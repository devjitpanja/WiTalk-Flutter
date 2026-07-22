import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'participant_avatar.dart';

class CircularSeatingLayout extends StatelessWidget {
  final List<Map<String, dynamic>> speakers;
  final String? hostUid;
  final String? activeSpeakerUid;
  final Function(Map<String, dynamic> speaker)? onSpeakerTap;

  const CircularSeatingLayout({
    super.key,
    required this.speakers,
    this.hostUid,
    this.activeSpeakerUid,
    this.onSpeakerTap,
  });

  @override
  Widget build(BuildContext context) {
    if (speakers.isEmpty) return const SizedBox.shrink();

    final count = speakers.length;
    final radius = count > 5 ? 120.0 : 90.0;

    return SizedBox(
      height: (radius * 2) + 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center Vibe element
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF007AFF).withOpacity(0.12),
              border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3), width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: Color(0xFF007AFF), size: 24),
                Text(
                  'Stage',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),

          // Circle speakers
          ...List.generate(count, (i) {
            final angle = (i * (2 * math.pi / count)) - (math.pi / 2);
            final x = radius * math.cos(angle);
            final y = radius * math.sin(angle);

            final speaker = speakers[i];
            final uid = speaker['uid']?.toString() ?? speaker['id']?.toString();
            final isHost = uid != null && hostUid != null && uid == hostUid;
            final isSpeaking = uid != null && activeSpeakerUid != null && uid == activeSpeakerUid;

            return Transform.translate(
              offset: Offset(x, y),
              child: ParticipantAvatar(
                uid: uid,
                name: speaker['name']?.toString() ?? speaker['display_name']?.toString(),
                avatarUrl: speaker['profile_pic']?.toString() ?? speaker['avatar']?.toString(),
                size: 50,
                isHost: isHost,
                isMuted: speaker['is_muted'] == true || speaker['is_muted'] == 1,
                isSpeaking: isSpeaking,
                onTap: () => onSpeakerTap?.call(speaker),
              ),
            );
          }),
        ],
      ),
    );
  }
}
