import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/audio_room_provider.dart';

class AudioRoomOverlay extends ConsumerWidget {
  const AudioRoomOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(audioRoomProvider);
    if (!roomState.isConnected || !roomState.isMinimised) return const SizedBox.shrink();

    final roomName = roomState.roomName;
    final hostImage = roomState.hostProfilePic;
    final isSpeaking = roomState.activeSpeakerUid != null;
    final onTap = () {
      ref.read(audioRoomProvider.notifier).toggleMinimised();
      context.push('/adda/live/${roomState.roomId}');
    };
    final onClose = () {
      ref.read(audioRoomProvider.notifier).leaveRoom();
    };
    return Positioned(
      bottom: kBottomNavigationBarHeight + 20,
      right: 20,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSpeaking ? const Color(0xFF007AFF) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hostImage != null)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(hostImage!),
                )
              else
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF2C2C2E),
                  child: Icon(Icons.mic, size: 16, color: Colors.white),
                ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Live Now',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
