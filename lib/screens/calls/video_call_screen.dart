import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class VideoCallScreen extends StatelessWidget {
  final String roomId;
  const VideoCallScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(icon: const Icon(Icons.call_end, color: AppColors.error, size: 28), onPressed: () => context.pop()),
      title: const Text('Video Call', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
    ),
    body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.videocam, color: Colors.white54, size: 80),
      SizedBox(height: 16),
      Text('Video call — LiveKit integration pending', style: TextStyle(color: Colors.white70, fontFamily: 'Outfit')),
    ])),
  );
}
