import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class LiveAudioRoomScreen extends StatelessWidget {
  final String roomId;
  const LiveAudioRoomScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Live Room', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
    ),
    body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🎙️', style: TextStyle(fontSize: 64)),
      SizedBox(height: 16),
      Text('Live Audio Room', style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      SizedBox(height: 8),
      Text('LiveKit integration pending backend setup', style: TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
    ])),
  );
}
