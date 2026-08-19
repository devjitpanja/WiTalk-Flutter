import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_alert_dialog.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kMaxPostImages = 20;
const _kMaxRecordSecs = 60;
const _kGalleryPageSize = 80;
const _kTabBarHeight = 56.0; // content height of mode tab bar (excl. safe area)

// ── Screen ────────────────────────────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  final String? initialMode; // 'Mini' | 'Post' | 'Thoughts'
  const CameraScreen({super.key, this.initialMode});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _initialized = false;
  FlashMode _flashMode = FlashMode.off;
  String _selectedMode = 'Post';

  // ── Recording (Mini) ────────────────────────────────────────────────────────
  bool _isRecording = false;
  int _recordingTime = 0;
  Timer? _recordingTimer;

  // ── Zoom ────────────────────────────────────────────────────────────────────
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  // ── Dual camera PIP ─────────────────────────────────────────────────────────
  bool _isDualMode = false;
  String _dualStep = 'idle';
  String? _firstDualPath;

  // ── Gallery (Post mode) ─────────────────────────────────────────────────────
  // false = camera view, true = gallery view
  bool _showGallery = true;
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _galleryAssets = [];
  bool _galleryLoading = false;
  bool _galleryHasMore = true;
  int _galleryPage = 0;
  final ScrollController _galleryScrollCtrl = ScrollController();
  String? _galleryError;
  bool _showAlbumDropdown = false;

  // ── Selection ───────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _selected = [];

  // ── Photo preview overlay ────────────────────────────────────────────────────
  int _previewIndex = -1;

  // ── Alert ────────────────────────────────────────────────────────────────────
  bool _alertVisible = false;
  String _alertTitle = '';
  String _alertMessage = '';
  String _alertType = 'info';
  List<DialogButtonConfig> _alertButtons = [];

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _selectedMode = widget.initialMode ?? 'Post';
    if (_selectedMode == 'Mini') _showGallery = false;
    _galleryScrollCtrl.addListener(_onGalleryScroll);
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _recordingTimer?.cancel();
    _controller?.dispose();
    _galleryScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Alert helper
  // ─────────────────────────────────────────────────────────────────────────────

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    List<DialogButtonConfig>? buttons,
  }) {
    if (!mounted) return;
    setState(() {
      _alertTitle = title;
      _alertMessage = message;
      _alertType = type;
      _alertButtons = buttons ??
          [DialogButtonConfig(text: 'OK', onPress: () => setState(() => _alertVisible = false))];
      _alertVisible = true;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Permissions + init
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _checkPermissionsAndInit() async {
    final camStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (camStatus.isGranted) {
      await _initCamera();
    } else {
      _showAlert(
        title: 'Camera Permission Required',
        message: 'Camera access is needed to take photos and videos.',
        type: 'danger',
        buttons: [
          DialogButtonConfig(
            text: 'Cancel',
            isCancel: true,
            onPress: () {
              setState(() => _alertVisible = false);
              if (mounted) context.pop();
            },
          ),
          DialogButtonConfig(
            text: 'Settings',
            onPress: () {
              setState(() => _alertVisible = false);
              openAppSettings();
            },
          ),
        ],
      );
    }

    if (_selectedMode == 'Post') {
      await _loadGallery();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Camera
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _startCamera(CameraDescription camera) async {
    await _controller?.dispose();
    final ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      _minZoom = await ctrl.getMinZoomLevel();
      _maxZoom = (await ctrl.getMaxZoomLevel()).clamp(1.0, 10.0);
      _currentZoom = _minZoom;
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('[CameraScreen] init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    if (mounted) setState(() => _initialized = false);
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_initialized) return;
    FlashMode next;
    switch (_flashMode) {
      case FlashMode.off:   next = FlashMode.torch; break;
      case FlashMode.torch: next = FlashMode.auto;  break;
      default:              next = FlashMode.off;
    }
    await _controller!.setFlashMode(next);
    if (mounted) setState(() => _flashMode = next);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Capture
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    if (_controller == null || !_initialized) return;
    if (_selected.length >= _kMaxPostImages) {
      _showAlert(title: 'Limit Reached', message: 'You can select up to $_kMaxPostImages photos.');
      return;
    }
    try {
      SystemSound.play(SystemSoundType.click);
      final file = await _controller!.takePicture();
      setState(() => _selected.add({'uri': file.path, 'type': 'image', 'fromCamera': true}));
    } catch (_) {
      _showAlert(title: 'Error', message: 'Failed to take photo.', type: 'danger');
    }
  }

  Future<void> _takeDualPhotoStep1() async {
    if (_controller == null || !_initialized) return;
    try {
      final file = await _controller!.takePicture();
      _firstDualPath = file.path;
      await _switchCamera();
      if (mounted) setState(() => _dualStep = 'waiting_second');
    } catch (_) {
      _showAlert(title: 'Error', message: 'Failed to capture first frame.', type: 'danger');
    }
  }

  Future<void> _takeDualPhotoStep2() async {
    if (_controller == null || !_initialized || _firstDualPath == null) return;
    try {
      final file = await _controller!.takePicture();
      setState(() {
        _selected.add({'uri': _firstDualPath, 'type': 'image', 'fromCamera': true});
        _selected.add({'uri': file.path, 'type': 'image', 'fromCamera': true});
        _dualStep = 'idle';
        _firstDualPath = null;
      });
    } catch (_) {
      setState(() { _dualStep = 'idle'; _firstDualPath = null; });
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_initialized || _isRecording) return;
    final hasVideo = _selected.any((m) => m['type'] == 'video');
    if (hasVideo) {
      _showAlert(
        title: 'Replace Video?',
        message: 'Only one video is allowed. Recording a new one will replace it.',
        type: 'warning',
        buttons: [
          DialogButtonConfig(
            text: 'Cancel',
            isCancel: true,
            onPress: () => setState(() => _alertVisible = false),
          ),
          DialogButtonConfig(
            text: 'Continue',
            onPress: () async {
              setState(() {
                _alertVisible = false;
                _selected.removeWhere((m) => m['type'] == 'video');
              });
              await _actuallyStartRecording();
            },
          ),
        ],
      );
      return;
    }
    await _actuallyStartRecording();
  }

  Future<void> _actuallyStartRecording() async {
    try {
      await _controller!.startVideoRecording();
      _recordingTime = 0;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _recordingTime++;
          if (_recordingTime >= _kMaxRecordSecs) _stopVideoRecording();
        });
      });
      setState(() => _isRecording = true);
    } catch (_) {
      _showAlert(title: 'Error', message: 'Failed to start recording.', type: 'danger');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isRecording) return;
    try {
      _recordingTimer?.cancel();
      final file = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _selected.add({'uri': file.path, 'type': 'video', 'duration': _recordingTime});
      });
      _finishAndNavigate();
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Gallery (photo_manager)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadGallery() async {
    if (!mounted) return;
    setState(() { _galleryLoading = true; _galleryError = null; });

    final perm = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!perm.isAuth && !perm.hasAccess) {
      setState(() {
        _galleryLoading = false;
        _galleryError = 'Photo access denied. Tap to open Settings.';
      });
      return;
    }

    final requestType = _selectedMode == 'Mini' ? RequestType.video : RequestType.image;
    try {
      final paths = await PhotoManager.getAssetPathList(type: requestType, onlyAll: false);
      if (!mounted) return;

      if (paths.isEmpty) {
        setState(() => _galleryLoading = false);
        return;
      }

      paths.sort((a, b) => (a.isAll ? 0 : 1).compareTo(b.isAll ? 0 : 1));
      _albums = paths;
      _selectedAlbum = paths.first;
      _galleryPage = 0;
      _galleryHasMore = true;
      _galleryAssets = [];
      await _loadMoreAssets();
    } catch (e) {
      debugPrint('[CameraScreen] gallery load error: $e');
    } finally {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  Future<void> _loadMoreAssets() async {
    if (!_galleryHasMore || _selectedAlbum == null || !mounted) return;
    final count = await _selectedAlbum!.assetCountAsync;
    if (_galleryPage * _kGalleryPageSize >= count) {
      _galleryHasMore = false;
      return;
    }
    final assets = await _selectedAlbum!.getAssetListPaged(
        page: _galleryPage, size: _kGalleryPageSize);
    if (assets.length < _kGalleryPageSize) _galleryHasMore = false;
    if (mounted) {
      setState(() {
        _galleryAssets.addAll(assets);
        _galleryPage++;
      });
    }
  }

  void _onGalleryScroll() {
    if (_galleryScrollCtrl.position.pixels >
        _galleryScrollCtrl.position.maxScrollExtent - 400) {
      _loadMoreAssets();
    }
  }

  Future<void> _switchAlbum(AssetPathEntity album) async {
    setState(() {
      _selectedAlbum = album;
      _galleryPage = 0;
      _galleryHasMore = true;
      _galleryAssets = [];
      _galleryLoading = true;
      _showAlbumDropdown = false;
    });
    await _loadMoreAssets();
    if (mounted) setState(() => _galleryLoading = false);
  }

  Future<void> _onGalleryAssetTapped(AssetEntity asset) async {
    if (_selectedMode == 'Mini') {
      final file = await asset.file;
      if (file == null) return;
      setState(() => _selected.add({'uri': file.path, 'type': 'video', 'duration': asset.duration}));
      _finishAndNavigate();
      return;
    }
    final alreadyIdx = _selected.indexWhere((s) => s['assetId'] == asset.id);
    if (alreadyIdx >= 0) {
      setState(() => _selected.removeAt(alreadyIdx));
    } else {
      if (_selected.length >= _kMaxPostImages) {
        _showAlert(title: 'Limit Reached', message: 'You can select up to $_kMaxPostImages photos.');
        return;
      }
      final file = await asset.file;
      if (file == null) return;
      setState(() => _selected.add({
        'assetId': asset.id,
        'uri': file.path,
        'type': 'image',
        'width': asset.width,
        'height': asset.height,
      }));
    }
  }

  int _selectionIndexOf(AssetEntity asset) =>
      _selected.indexWhere((s) => s['assetId'] == asset.id);

  void _showAlbumPickerSheet() {
    if (_albums.isEmpty) return;
    setState(() => _showAlbumDropdown = !_showAlbumDropdown);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Cropping + navigation
  // ─────────────────────────────────────────────────────────────────────────────

  void _finishAndNavigate() {
    if (_selected.isEmpty) { context.pop(); return; }
    if (_selectedMode == 'Post' && _selected.every((s) => s['type'] == 'image')) {
      // Push to MediaEditScreen — it handles ratio selection, per-image editing, and returns
      // the result up the stack; CameraScreen pops with that result.
      _navigateToMediaEdit();
    } else {
      _doNavigate(_selected);
    }
  }

  Future<void> _navigateToMediaEdit() async {
    final media = _selected.map((m) => {
      'uri': m['uri'],
      'type': m['type'],
      'width': m['width'] ?? 1080,
      'height': m['height'] ?? 1080,
      if (m['duration'] != null) 'duration': m['duration'],
    }).toList();
    final result = await context.push<Map<String, dynamic>>(
      '/media-edit',
      extra: {'media': media},
    );
    if (!mounted) return;
    if (result != null) {
      context.pop(result);
    }
  }

  void _doNavigate(List<Map<String, dynamic>> media) {
    final clean = media.map((m) => {
      'uri': m['uri'],
      'type': m['type'],
      'width': m['width'] ?? 1080,
      'height': m['height'] ?? 1080,
      if (m['duration'] != null) 'duration': m['duration'],
    }).toList();
    context.pop({'capturedMedia': clean, 'fromCamera': true});
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  String _formatTime(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.torch: return Icons.flash_on;
      case FlashMode.auto:  return Icons.flash_auto;
      default:              return Icons.flash_off;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Camera preview — full-screen fill via OverflowBox + FittedBox
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    if (!_initialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return CameraPreview(_controller!);

    final pw = previewSize.width < previewSize.height
        ? previewSize.width.toDouble()
        : previewSize.height.toDouble();
    final ph = previewSize.width < previewSize.height
        ? previewSize.height.toDouble()
        : previewSize.width.toDouble();

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: pw,
            height: ph,
            child: GestureDetector(
              onScaleStart: (d) => _baseZoom = _currentZoom,
              onScaleUpdate: (d) {
                final zoom = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
                _controller?.setZoomLevel(zoom);
                setState(() => _currentZoom = zoom);
              },
              child: CameraPreview(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Photo preview overlay
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPhotoPreview() {
    if (_previewIndex < 0 || _previewIndex >= _selected.length) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: _PhotoPreviewOverlay(
        items: List<Map<String, dynamic>>.from(_selected),
        initialIndex: _previewIndex,
        onClose: () => setState(() => _previewIndex = -1),
        onDelete: (i) => setState(() {
          _selected.removeAt(i);
          _previewIndex = -1;
        }),
        onSave: (path) async {
          try {
            await PhotoManager.editor.saveImageWithPath(path, title: 'WiTalk');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to gallery', style: TextStyle(fontFamily: 'Outfit')),
                backgroundColor: Color(0xFF1A1A1A),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save', style: TextStyle(fontFamily: 'Outfit')),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isGalleryMode = _selectedMode == 'Post' && _showGallery;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // Bottom of shutter/bottom-controls row sits just above the tab bar
    final controlsBottom = safeBottom + _kTabBarHeight + 16;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen camera preview ────────────────────────────────────────
          Positioned.fill(child: _buildCameraPreview()),

          // ── Post-mode: gallery replaces camera view ───────────────────────────
          if (isGalleryMode) _buildGalleryView(),

          // ── Top bar — Positioned to avoid Stack's cross-axis centering bug ────
          Positioned(
            top: 0, left: 0, right: 0,
            child: isGalleryMode ? _buildGalleryTopBar() : _buildCameraTopBar(),
          ),

          // ── Recording timer + progress bar (Mini) ─────────────────────────────
          if (_isRecording) _buildRecordingIndicator(),

          // ── Mode tabs at very bottom (hidden during recording) ────────────────
          if (!_isRecording)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildModeTabs(),
            ),

          // ── Bottom shutter controls (camera view only) ────────────────────────
          if (!isGalleryMode)
            Positioned(
              bottom: controlsBottom,
              left: 24, right: 24,
              child: _buildShutterRow(),
            ),

          // ── Selected thumbnails strip (camera view, Post mode) ────────────────
          if (!isGalleryMode && _selectedMode == 'Post' && _selected.isNotEmpty)
            Positioned(
              bottom: controlsBottom + 88,
              left: 0, right: 0,
              child: _buildSelectedStrip(),
            ),

          // ── Photo preview overlay ─────────────────────────────────────────────
          if (_previewIndex >= 0) _buildPhotoPreview(),

          // ── Alert ─────────────────────────────────────────────────────────────
          CustomAlertDialog(
            visible: _alertVisible,
            title: _alertTitle,
            message: _alertMessage,
            type: _alertType,
            buttons: _alertButtons,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Top bars
  // ─────────────────────────────────────────────────────────────────────────────

  // Camera-view top bar: X  flash(back only)  flip
  Widget _buildCameraTopBar() {
    final isFront = _cameras.isNotEmpty &&
        _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TopBtn(icon: Icons.close, onTap: () => context.pop()),
            const Spacer(),
            if (!isFront) _TopBtn(icon: _flashIcon, onTap: _toggleFlash),
            _TopBtn(icon: Icons.flip_camera_ios, onTap: _switchCamera),
          ],
        ),
      ),
    );
  }

  // Gallery-view top bar: X  |  Album name ▼ (centered)  |  Next
  Widget _buildGalleryTopBar() {
    return SafeArea(
      child: SizedBox(
        height: 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TopBtn(icon: Icons.close, onTap: () => context.pop()),
            Expanded(
              child: GestureDetector(
                onTap: _showAlbumPickerSheet,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedAlbum?.name ?? 'Recent',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Icon(
                        _showAlbumDropdown
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _selected.isNotEmpty ? _finishAndNavigate : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Next',
                  style: TextStyle(
                    color: _selected.isNotEmpty ? Colors.white : Colors.white38,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Recording indicator
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_formatTime(_recordingTime),
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: _recordingTime / _kMaxRecordSecs,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Mode tabs  (Mini | Post | Thoughts)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildModeTabs() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _kTabBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ModeTab(
                label: 'Mini',
                selected: _selectedMode == 'Mini',
                onTap: () => setState(() {
                  _selectedMode = 'Mini';
                  _showGallery = false;
                }),
              ),
              _ModeTab(
                label: 'Post',
                selected: _selectedMode == 'Post',
                onTap: () {
                  setState(() {
                    _selectedMode = 'Post';
                    _showGallery = true;
                  });
                  if (_galleryAssets.isEmpty) _loadGallery();
                },
              ),
              _ModeTab(
                label: 'Thoughts',
                selected: _selectedMode == 'Thoughts',
                onTap: () => context.pushReplacement('/create-post', extra: {
                  'capturedMedia': <Map<String, dynamic>>[],
                  'fromCamera': true,
                  'thoughtsMode': true,
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shutter row (camera view)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildShutterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Gallery shortcut
        GestureDetector(
          onTap: () {
            if (_selectedMode == 'Post') {
              setState(() => _showGallery = true);
              if (_galleryAssets.isEmpty) _loadGallery();
            }
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
          ),
        ),

        // Shutter button
        GestureDetector(
          onTap: _onShutterTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: Colors.transparent,
            ),
            child: Center(
              child: _selectedMode == 'Mini'
                  ? (_isRecording
                      // Recording → red rounded square stop indicator
                      ? Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )
                      // Not recording in Mini → red circle (record)
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ))
                  // Post mode → white circle shutter
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),

        // Done button or spacer
        if (_selected.isNotEmpty)
          GestureDetector(
            onTap: _finishAndNavigate,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: AppColors.primaryButton, shape: BoxShape.circle),
              child: Center(
                child: _selected.length > 1
                    ? Text('${_selected.length}',
                        style: const TextStyle(
                            color: Colors.white, fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700, fontSize: 18))
                    : const Icon(Icons.check, color: Colors.white, size: 28),
              ),
            ),
          )
        else
          const SizedBox(width: 52, height: 52),
      ],
    );
  }

  void _onShutterTap() {
    if (_selectedMode == 'Mini') {
      _isRecording ? _stopVideoRecording() : _startVideoRecording();
    } else {
      if (_isDualMode) {
        _dualStep == 'idle' ? _takeDualPhotoStep1() : _takeDualPhotoStep2();
      } else {
        _takePhoto();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Selected thumbnails strip
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSelectedStrip() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _selected.length,
        separatorBuilder: (c, i) => const SizedBox(width: 6),
        itemBuilder: (c, i) {
          final item = _selected[i];
          return GestureDetector(
            onTap: () => setState(() => _previewIndex = i),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(item['uri'] as String),
                      width: 52, height: 52, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 2, right: 2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.remove_red_eye, size: 9, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Gallery view (Post mode)
  //
  // First two grid cells are camera + gallery shortcut tiles.
  // Top bar (gallery variant) is rendered above this in the Stack.
  // Mode tabs are rendered below this in the Stack.
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildGalleryView() {
    final topInset = MediaQuery.of(context).padding.top + 52.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0D1017),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: topInset),
                Expanded(
                  child: _galleryLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryButton, strokeWidth: 2))
                      : _galleryError != null
                          ? _buildGalleryError()
                          : GridView.builder(
                              controller: _galleryScrollCtrl,
                              padding: EdgeInsets.only(
                                  bottom: safeBottom + _kTabBarHeight + 8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2,
                              ),
                              itemCount: 2 + _galleryAssets.length,
                              itemBuilder: (c, i) {
                                if (i == 0) return _buildCameraShortcutTile();
                                if (i == 1) return _buildGalleryShortcutTile();
                                final asset = _galleryAssets[i - 2];
                                return _GalleryTile(
                                  asset: asset,
                                  selectionIndex: _selectionIndexOf(asset),
                                  totalSelected: _selected.length,
                                  onTap: () => _onGalleryAssetTapped(asset),
                                );
                              },
                            ),
                ),
              ],
            ),
            // Inline album dropdown overlay
            if (_showAlbumDropdown)
              Positioned(
                top: topInset,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _albums.length,
                      itemBuilder: (ctx, i) {
                        final album = _albums[i];
                        final isSel = album.id == _selectedAlbum?.id;
                        return GestureDetector(
                          onTap: () => _switchAlbum(album),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primaryButton.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: const Border(
                                bottom: BorderSide(
                                  color: Color(0x1AFFFFFF),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  album.name,
                                  style: TextStyle(
                                    color: isSel
                                        ? AppColors.primaryButton
                                        : Colors.white,
                                    fontFamily: 'Outfit',
                                    fontWeight: isSel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isSel)
                                  const Icon(Icons.check,
                                      color: AppColors.primaryButton, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraShortcutTile() {
    return GestureDetector(
      onTap: () => setState(() => _showGallery = false),
      child: Container(
        color: const Color(0xFF1C1C1E),
        child: const Center(
          child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildGalleryShortcutTile() {
    return Container(
      color: const Color(0xFF1A2A4A),
      child: const Center(
        child: Icon(Icons.photo_library_outlined, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildGalleryError() {
    return Center(
      child: GestureDetector(
        onTap: () => openAppSettings(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(_galleryError ?? 'Photo access denied.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Outfit',
                    fontSize: 14)),
            const SizedBox(height: 8),
            const Text('Tap to open Settings',
                style: TextStyle(
                    color: AppColors.primaryButton,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )),
        ),
      );
}

// ── Gallery thumbnail tile ────────────────────────────────────────────────────

class _GalleryTile extends StatelessWidget {
  final AssetEntity asset;
  final int selectionIndex;
  final int totalSelected;
  final VoidCallback onTap;
  const _GalleryTile({
    required this.asset,
    required this.selectionIndex,
    required this.totalSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionIndex >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetThumb(asset: asset),
          if (!isSelected && totalSelected > 0)
            Container(color: Colors.black38),
          if (isSelected)
            Container(
              color: Colors.black26,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: AppColors.primaryButton, shape: BoxShape.circle),
                child: Center(
                  child: Text('${selectionIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
            ),
          if (asset.type == AssetType.video)
            Positioned(
              bottom: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(_fmtDur(asset.duration),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'Outfit')),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtDur(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

// ── Asset thumbnail image provider ───────────────────────────────────────────

class _AssetThumb extends StatelessWidget {
  final AssetEntity asset;
  const _AssetThumb({required this.asset});

  @override
  Widget build(BuildContext context) => Image(
        image: _AssetThumbProvider(asset),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(color: Colors.white10),
      );
}

class _AssetThumbProvider extends ImageProvider<_AssetThumbProvider> {
  final AssetEntity asset;
  const _AssetThumbProvider(this.asset);

  @override
  Future<_AssetThumbProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _AssetThumbProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _load(), scale: 1.0);
  }

  Future<ui.Codec> _load() async {
    final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
    if (bytes == null) throw Exception('No thumbnail data for ${asset.id}');
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return ui.instantiateImageCodecFromBuffer(buffer);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AssetThumbProvider && asset.id == other.asset.id;

  @override
  int get hashCode => asset.id.hashCode;
}

// ── Photo preview carousel overlay ───────────────────────────────────────────

class _PhotoPreviewOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;
  final VoidCallback onClose;
  final void Function(int index) onDelete;
  final Future<void> Function(String path) onSave;

  const _PhotoPreviewOverlay({
    required this.items,
    required this.initialIndex,
    required this.onClose,
    required this.onDelete,
    required this.onSave,
  });

  @override
  State<_PhotoPreviewOverlay> createState() => _PhotoPreviewOverlayState();
}

class _PhotoPreviewOverlayState extends State<_PhotoPreviewOverlay> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _TopBtn(icon: Icons.arrow_back, onTap: widget.onClose),
                  const Spacer(),
                  Text(
                    '${_current + 1} / ${widget.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // ── Swipeable images ─────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      File(widget.items[i]['uri'] as String),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // ── Dot indicators ───────────────────────────────────────────────
            if (widget.items.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.items.length, (i) {
                    final active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),

            // ── Action buttons ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onDelete(_current),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onSave(widget.items[_current]['uri'] as String),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryButton,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_alt, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save to Gallery',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
