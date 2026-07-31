import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/audio_room_provider.dart';

class AudioRoomOverlay extends ConsumerStatefulWidget {
  const AudioRoomOverlay({super.key});

  @override
  ConsumerState<AudioRoomOverlay> createState() => _AudioRoomOverlayState();
}

class _AudioRoomOverlayState extends ConsumerState<AudioRoomOverlay> {
  static const double _bubbleWidth = 220;
  static const double _bubbleHeight = 56;
  static const double _margin = 16;

  Offset? _position;

  void _snapToEdge(Size screen) {
    final pos = _position!;
    final mid = screen.width / 2;
    final snappedX = (pos.dx + _bubbleWidth / 2) < mid
        ? _margin
        : screen.width - _bubbleWidth - _margin;
    final clampedY = pos.dy.clamp(
      60.0,
      screen.height - _bubbleHeight - kBottomNavigationBarHeight - 20,
    );
    setState(() => _position = Offset(snappedX, clampedY));
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(audioRoomProvider);
    if (!roomState.isConnected || !roomState.isMinimised) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);

    // Default position: bottom-right above nav bar
    _position ??= Offset(
      screen.width - _bubbleWidth - _margin,
      screen.height - _bubbleHeight - kBottomNavigationBarHeight - 24,
    );

    final isSpeaking = roomState.activeSpeakerUid != null;
    final hostImage = roomState.hostProfilePic;
    final roomName = roomState.roomName;

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _position = Offset(
              (_position!.dx + d.delta.dx).clamp(0.0, screen.width - _bubbleWidth),
              (_position!.dy + d.delta.dy).clamp(0.0, screen.height - _bubbleHeight),
            );
          });
        },
        onPanEnd: (_) => _snapToEdge(screen),
        onTap: () {
          ref.read(audioRoomProvider.notifier).restoreRoom();
          context.push(
            '/live-audio/${roomState.roomId}',
            extra: {'is_host': roomState.isHost, 'restore': true},
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _bubbleWidth,
            height: _bubbleHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withOpacity(0.96),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isSpeaking ? const Color(0xFF2563EB) : const Color(0xFF2C2C2E),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (hostImage != null)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(hostImage),
                  )
                else
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF2C2C2E),
                    child: Icon(Icons.mic, size: 16, color: Colors.white),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Live Now',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      Text(
                        roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(audioRoomProvider.notifier).leaveRoom(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
