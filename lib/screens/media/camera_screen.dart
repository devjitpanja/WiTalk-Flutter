import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_alert_dialog.dart';

class CameraScreen extends StatefulWidget {
  final String? initialMode; // 'Mini' | 'Post'
  const CameraScreen({super.key, this.initialMode});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _initialized = false;
  FlashMode _flashMode = FlashMode.off;
  String _selectedMode = 'Mini'; // 'Mini' or 'Post'

  // Recording state for Mini mode
  bool _isRecording = false;
  int _recordingTime = 0; // in seconds
  Timer? _recordingTimer;
  static const int _maxRecordingTime = 60; // 60s max for Mini

  // Zoom
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  // Dual camera PIP state
  bool _isDualMode = false;
  String _dualStep = 'idle'; // 'idle' | 'waiting_second' | 'processing'
  String? _firstDualPath;

  // Captured media list
  final List<Map<String, dynamic>> _capturedMedia = [];

  // Alert Dialog state
  bool _alertVisible = false;
  String _alertTitle = '';
  String _alertMessage = '';
  String _alertType = 'info';
  List<DialogButtonConfig> _alertButtons = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.initialMode != null) {
      _selectedMode = widget.initialMode!;
    }
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    List<DialogButtonConfig>? buttons,
  }) {
    setState(() {
      _alertTitle = title;
      _alertMessage = message;
      _alertType = type;
      _alertButtons = buttons ??
          [
            DialogButtonConfig(
              text: 'OK',
              onPress: () => setState(() => _alertVisible = false),
            )
          ];
      _alertVisible = true;
    });
  }

  Future<void> _checkPermissionsAndInit() async {
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (cameraStatus.isGranted) {
      await _initCamera();
    } else {
      _showAlert(
        title: 'Permission Denied',
        message: 'Camera permission is required to take photos and record videos.',
        type: 'danger',
        buttons: [
          DialogButtonConfig(
            text: 'Cancel',
            isCancel: true,
            onPress: () {
              setState(() => _alertVisible = false);
              context.pop();
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
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;

    try {
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 10.0);
      _currentZoom = _minZoom;
      if (mounted) setState(() => _initialized = true);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    setState(() => _initialized = false);
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_initialized) return;
    FlashMode next;
    switch (_flashMode) {
      case FlashMode.off:
        next = FlashMode.torch;
        break;
      case FlashMode.torch:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
      default:
        next = FlashMode.off;
        break;
    }
    await _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  void _startRecordingTimer() {
    _recordingTime = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingTime++;
        if (_selectedMode == 'Mini' && _recordingTime >= _maxRecordingTime) {
          _stopVideoRecording();
        }
      });
    });
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_initialized || _isRecording) return;

    final hasVideo = _capturedMedia.any((m) => m['type'] == 'video');
    if (hasVideo) {
      _showAlert(
        title: 'Replace Video?',
        message: 'Only one video is allowed. Recording a new video will replace the previous one.',
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
                _capturedMedia.removeWhere((m) => m['type'] == 'video');
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
      setState(() => _isRecording = true);
      _startRecordingTimer();
    } catch (_) {
      _showAlert(title: 'Error', message: 'Failed to start recording.', type: 'danger');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isRecording) return;
    try {
      _recordingTimer?.cancel();
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      _capturedMedia.add({
        'uri': file.path,
        'type': 'video',
        'duration': _recordingTime,
      });

      _finishAndNavigate();
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_initialized) return;

    try {
      final file = await _controller!.takePicture();
      _capturedMedia.add({
        'uri': file.path,
        'type': 'image',
        'width': 1080,
        'height': 1080,
      });

      _finishAndNavigate();
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
      setState(() => _dualStep = 'waiting_second');
    } catch (_) {
      _showAlert(title: 'Error', message: 'Failed to capture step 1 photo.', type: 'danger');
    }
  }

  Future<void> _takeDualPhotoStep2() async {
    if (_controller == null || !_initialized || _firstDualPath == null) return;
    try {
      final file = await _controller!.takePicture();
      _capturedMedia.add({
        'uri': file.path,
        'type': 'image',
        'width': 1080,
        'height': 1080,
      });
      setState(() => _dualStep = 'idle');
      _finishAndNavigate();
    } catch (_) {
      setState(() => _dualStep = 'idle');
    }
  }

  void _finishAndNavigate() {
    if (_capturedMedia.isEmpty) {
      context.pop();
      return;
    }
    context.pop({
      'capturedMedia': _capturedMedia,
      'fromCamera': true,
    });
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    if (_selectedMode == 'Mini') {
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        _capturedMedia.add({
          'uri': video.path,
          'type': 'video',
          'duration': 0,
        });
        _finishAndNavigate();
      }
    } else {
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        _capturedMedia.addAll(images.map((img) => {
              'uri': img.path,
              'type': 'image',
              'width': 1080,
              'height': 1080,
            }));
        _finishAndNavigate();
      }
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Preview ──
          if (_initialized && _controller != null)
            GestureDetector(
              onScaleUpdate: (details) {
                final zoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
                _controller?.setZoomLevel(zoom);
                setState(() => _currentZoom = zoom);
              },
              child: Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ── Top Bar Controls ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  // Dual Mode toggle icon
                  IconButton(
                    icon: Icon(
                      _isDualMode ? Icons.filter_center_focus : Icons.camera_alt_outlined,
                      color: _isDualMode ? AppColors.primaryButton : Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      setState(() {
                        _isDualMode = !_isDualMode;
                        _dualStep = 'idle';
                      });
                    },
                  ),
                  // Flash toggle
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.off
                          ? Icons.flash_off
                          : _flashMode == FlashMode.torch
                              ? Icons.flash_on
                              : Icons.flash_auto,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: _toggleFlash,
                  ),
                  // Switch Camera
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 26),
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),
          ),

          // ── Recording Timer (Mini Mode) ──
          if (_isRecording)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_recordingTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Mode Switcher (Mini vs Post) ──
          if (!_isRecording)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedMode = 'Mini'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'Mini' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Mini',
                        style: TextStyle(
                          color: _selectedMode == 'Mini' ? Colors.black : Colors.white70,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _selectedMode = 'Post'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'Post' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Post',
                        style: TextStyle(
                          color: _selectedMode == 'Post' ? Colors.black : Colors.white70,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Bottom Shutter & Gallery Controls ──
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Gallery button
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white54, width: 1.5),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
                  ),
                ),

                // Shutter Button
                GestureDetector(
                  onTap: () {
                    if (_isDualMode) {
                      if (_dualStep == 'idle') {
                        _takeDualPhotoStep1();
                      } else {
                        _takeDualPhotoStep2();
                      }
                    } else if (_selectedMode == 'Mini') {
                      if (_isRecording) {
                        _stopVideoRecording();
                      } else {
                        _startVideoRecording();
                      }
                    } else {
                      _takePhoto();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isRecording ? Colors.red : Colors.white.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.white,
                        ),
                        child: _isRecording
                            ? const Icon(Icons.stop, color: Colors.white, size: 32)
                            : null,
                      ),
                    ),
                  ),
                ),

                // Placeholder / Done button
                if (_capturedMedia.isNotEmpty)
                  GestureDetector(
                    onTap: _finishAndNavigate,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryButton,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 28),
                    ),
                  )
                else
                  const SizedBox(width: 48, height: 48),
              ],
            ),
          ),

          // ── Custom Alert Dialog ──
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
}
