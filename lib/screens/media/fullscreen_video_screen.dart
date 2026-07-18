import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../theme/app_colors.dart';

class FullscreenVideoScreen extends StatefulWidget {
  final String url;
  const FullscreenVideoScreen({super.key, required this.url});
  @override
  State<FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}
class _FullscreenVideoScreenState extends State<FullscreenVideoScreen> {
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
    _init();
  }
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _vpCtrl?.dispose(); _chewieCtrl?.dispose(); super.dispose();
  }
  Future<void> _init() async {
    _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _vpCtrl!.initialize();
    _chewieCtrl = ChewieController(videoPlayerController: _vpCtrl!, autoPlay: true, looping: false, fullScreenByDefault: true, allowFullScreen: true);
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      _chewieCtrl != null ? Chewie(controller: _chewieCtrl!) : const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
      SafeArea(child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => context.pop())),
    ]),
  );
}