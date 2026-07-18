import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../theme/app_colors.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isRecording = false;
  bool _initialized = false;
  FlashMode _flashMode = FlashMode.off;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller?.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _capture() async {
    if (_controller == null || !_initialized) return;
    if (_isVideo) {
      if (_isRecording) {
        final file = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);
        if (mounted) context.pop({'type': 'video', 'path': file.path});
      } else {
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
      }
    } else {
      final file = await _controller!.takePicture();
      if (mounted) context.pop({'type': 'photo', 'path': file.path});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera preview
        if (_initialized && _controller != null)
          Positioned.fill(child: CameraPreview(_controller!))
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Top controls
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => context.pop()),
            const Spacer(),
            IconButton(icon: Icon(_flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on, color: Colors.white, size: 26), onPressed: _toggleFlash),
            IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 26), onPressed: _switchCamera),
          ]),
        )),

        // Mode toggle
        Positioned(top: 80, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(onTap: () => setState(() => _isVideo = false),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: !_isVideo ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
              child: Text('Photo', style: TextStyle(color: _isVideo ? Colors.white : Colors.black, fontFamily: 'Outfit', fontWeight: FontWeight.w600)))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => setState(() => _isVideo = true),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: _isVideo ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
              child: Text('Video', style: TextStyle(color: !_isVideo ? Colors.white : Colors.black, fontFamily: 'Outfit', fontWeight: FontWeight.w600)))),
        ])),

        // Capture button
        Positioned(bottom: 48, left: 0, right: 0, child: Center(child: GestureDetector(
          onTap: _capture,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _isRecording ? Colors.red : Colors.white.withOpacity(0.2),
            ),
            child: _isRecording ? const Icon(Icons.stop, color: Colors.white, size: 36) : null,
          ),
        ))),
      ]),
    );
  }
}
