import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';

class VoiceCallScreen extends StatelessWidget {
  final String roomId;
  const VoiceCallScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF1A1A2E),
    body: SafeArea(child: Column(children: [
      const SizedBox(height: 60),
      const CircleAvatar(radius: 60, backgroundColor: AppColors.border, child: Icon(Icons.person, color: Colors.white, size: 56)),
      const SizedBox(height: 24),
      const Text('Voice Call', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
      const SizedBox(height: 8),
      const Text('Connecting...', style: TextStyle(color: Colors.white60, fontSize: 16, fontFamily: 'Outfit')),
      const Spacer(),
      Padding(padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 32)),
        )),
    ])),
  );
}
