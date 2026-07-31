import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../theme/app_colors.dart';

// ── Aspect ratio ──────────────────────────────────────────────────────────────

enum _Ratio { square, landscape, portrait }

extension _RatioExt on _Ratio {
  double get value {
    switch (this) {
      case _Ratio.square:    return 1.0;
      case _Ratio.landscape: return 16 / 9;
      case _Ratio.portrait:  return 4 / 5;
    }
  }

  String get label {
    switch (this) {
      case _Ratio.square:    return 'Square';
      case _Ratio.landscape: return 'Landscape';
      case _Ratio.portrait:  return 'Portrait';
    }
  }

  IconData get icon {
    switch (this) {
      case _Ratio.square:    return Icons.crop_square;
      case _Ratio.landscape: return Icons.crop_landscape;
      case _Ratio.portrait:  return Icons.crop_portrait;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MediaEditScreen extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  const MediaEditScreen({super.key, required this.media});

  @override
  State<MediaEditScreen> createState() => _MediaEditScreenState();
}

class _MediaEditScreenState extends State<MediaEditScreen> {
  late List<Map<String, dynamic>> _media;
  int _activeIndex = 0;
  late _Ratio _ratio;
  bool _showRatioPicker = false;
  bool _isProcessing = false;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _media = List<Map<String, dynamic>>.from(widget.media);
    _ratio = _autoDetectRatio();
    _pageCtrl = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  _Ratio _autoDetectRatio() {
    int landscape = 0, portrait = 0;
    for (final m in widget.media) {
      final w = (m['width'] as int?) ?? 1;
      final h = (m['height'] as int?) ?? 1;
      if (w > h) landscape++;
      else if (h > w) portrait++;
    }
    if (landscape > portrait) return _Ratio.landscape;
    if (portrait > 0) return _Ratio.portrait;
    return _Ratio.square;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Editor
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _openEditor(int index) async {
    final item = _media[index];
    if (item['type'] != 'image') return;

    Uint8List? resultBytes;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProImageEditor.file(
          File(item['uri'] as String),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              resultBytes = bytes;
              Navigator.pop(context);
            },
          ),
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.material,
            imageGeneration: ImageGenerationConfigs(
              outputFormat: OutputFormat.jpg,
              jpegQuality: 90,
            ),
            i18n: const I18n(done: 'Done', cancel: 'Cancel'),
            cropRotateEditor: CropRotateEditorConfigs(
              initAspectRatio: _ratio.value,
            ),
            paintEditor: const PaintEditorConfigs(),
            textEditor: const TextEditorConfigs(),
            filterEditor: const FilterEditorConfigs(),
            tuneEditor: const TuneEditorConfigs(),
            blurEditor: const BlurEditorConfigs(),
            emojiEditor: const EmojiEditorConfigs(),
          ),
        ),
      ),
    );

    if (resultBytes != null && mounted) {
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/edit_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(resultBytes!);
      setState(() => _media[index] = {..._media[index], 'uri': out.path});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Next — crop all images to chosen ratio, then return to caller
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _onNext() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final dir = await getTemporaryDirectory();
      final edited = List<Map<String, dynamic>>.from(_media);
      for (int i = 0; i < edited.length; i++) {
        final item = edited[i];
        if (item['type'] != 'image') continue;
        final bytes = await File(item['uri'] as String).readAsBytes();
        final cropped = await _centerCropToRatio(bytes, _ratio.value);
        final out = File('${dir.path}/final_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await out.writeAsBytes(cropped);
        edited[i] = {...item, 'uri': out.path};
      }
      if (mounted) _doReturn(edited);
    } catch (e) {
      debugPrint('[MediaEditScreen] crop error: $e');
      if (mounted) _doReturn(_media);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _doReturn(List<Map<String, dynamic>> media) {
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
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showRatioPicker
            ? () => setState(() => _showRatioPicker = false)
            : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: safeTop),
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildCarousel(size),
                const Spacer(),
                _buildBottomBar(safeBottom),
              ],
            ),
            if (_showRatioPicker) _buildRatioPickerOverlay(safeBottom),
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryButton),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Top bar
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
            onPressed: () => context.pop(),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          ),
          // Center title
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                if (_media.length > 1)
                  const SizedBox(height: 4),
                if (_media.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _media.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _activeIndex ? 16 : 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _activeIndex ? Colors.white : Colors.white38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Next button (top-right)
          GestureDetector(
            onTap: _isProcessing ? null : _onNext,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _isProcessing ? AppColors.primaryButton.withValues(alpha: 0.5) : AppColors.primaryButton,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Carousel
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCarousel(Size size) {
    final previewWidth = size.width * 0.88;
    final rawHeight = previewWidth / _ratio.value;
    final previewHeight = rawHeight.clamp(200.0, size.height * 0.58);

    return SizedBox(
      height: previewHeight,
      child: PageView.builder(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _activeIndex = i),
        itemCount: _media.length,
        itemBuilder: (ctx, i) {
          final item = _media[i];
          final isActive = i == _activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(
              horizontal: 5,
              vertical: isActive ? 0 : 14,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isActive ? 4 : 10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(item['uri'] as String),
                    fit: BoxFit.cover,
                  ),
                  if (!isActive) Container(color: Colors.black38),
                  // Remove button
                  if (isActive && _media.length > 1)
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _media.removeAt(i);
                            if (_activeIndex >= _media.length) {
                              _activeIndex = _media.length - 1;
                            }
                          });
                        },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 1),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bottom bar — ratio pill (left) + edit button (right)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(double safeBottom) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, safeBottom + 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ratio selector pill
          GestureDetector(
            onTap: () => setState(() => _showRatioPicker = !_showRatioPicker),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_ratio.icon, color: Colors.white, size: 17),
                  const SizedBox(width: 5),
                  Text(
                    _ratio.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 15),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Edit button
          GestureDetector(
            onTap: () => _openEditor(_activeIndex),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, color: Colors.white, size: 17),
                  SizedBox(width: 6),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Ratio picker overlay
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildRatioPickerOverlay(double safeBottom) {
    return Positioned(
      bottom: safeBottom + 60,
      left: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _Ratio.values.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              final isSel = r == _ratio;
              final isLast = idx == _Ratio.values.length - 1;
              return GestureDetector(
                onTap: () => setState(() {
                  _ratio = r;
                  _showRatioPicker = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Icon(r.icon,
                          color: isSel ? AppColors.primaryButton : Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(
                        r.label,
                        style: TextStyle(
                          color: isSel ? AppColors.primaryButton : Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                      if (isSel) ...[
                        const Spacer(),
                        Icon(Icons.check, color: AppColors.primaryButton, size: 17),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Centre-crop helper ────────────────────────────────────────────────────────

Future<Uint8List> _centerCropToRatio(Uint8List bytes, double ratio) async {
  final codec = await ui.instantiateImageCodecFromBuffer(
    await ui.ImmutableBuffer.fromUint8List(bytes),
  );
  final frame = await codec.getNextFrame();
  final src = frame.image;

  final sw = src.width.toDouble();
  final sh = src.height.toDouble();
  final srcRatio = sw / sh;

  double cropW, cropH;
  if (srcRatio > ratio) {
    cropH = sh;
    cropW = sh * ratio;
  } else {
    cropW = sw;
    cropH = sw / ratio;
  }

  final left = (sw - cropW) / 2;
  final top = (sh - cropH) / 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    src,
    Rect.fromLTWH(left, top, cropW, cropH),
    Rect.fromLTWH(0, 0, cropW, cropH),
    Paint(),
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(cropW.round(), cropH.round());
  final pngData = await output.toByteData(format: ui.ImageByteFormat.png);
  return pngData!.buffer.asUint8List();
}
