import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Pixel-perfect Flutter port of the RN ParticipantAvatar component.
/// Renders a circular avatar with:
///  - Profile image or letter fallback
///  - Gold animated ring when speaking
///  - Crown/host badge (top-left)
///  - Mic-off badge (bottom-right)
///  - Name label below
class ParticipantAvatar extends StatelessWidget {
  final String? uid;
  final String? name;
  final String? avatarUrl;
  final bool isHost;
  final bool isAdmin;
  final bool isMuted;
  final bool isSpeaking;
  final bool isSelf;
  final double size;
  final VoidCallback? onTap;
  final bool showName;

  const ParticipantAvatar({
    super.key,
    this.uid,
    this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isAdmin = false,
    this.isMuted = true,
    this.isSpeaking = false,
    this.isSelf = false,
    this.size = 56,
    this.onTap,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.isNotEmpty == true ? name![0] : (uid?.isNotEmpty == true ? uid![0] : 'U')).toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + 8,
            height: size + 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speaking ring (gold pulsing border)
                if (isSpeaking)
                  Container(
                    width: size + 8,
                    height: size + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF5B9AFF),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B9AFF).withAlpha(100),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  )
                else if (isHost)
                  Container(
                    width: size + 8,
                    height: size + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFA726),
                        width: 2.5,
                      ),
                    ),
                  ),

                // Avatar circle
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildInitialAvatar(initial),
                          placeholder: (_, __) => _buildInitialAvatar(initial),
                        )
                      : _buildInitialAvatar(initial),
                ),

                // Crown badge — top left
                if (isHost)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1017),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFA726), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text('👑', style: TextStyle(fontSize: 9)),
                    ),
                  ),

                // Mic-off badge — bottom right
                if (isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D1017), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.mic_off, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          if (showName) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: size + 8,
              child: Text(
                isSelf ? 'You' : (name ?? uid ?? 'User'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      color: const Color(0xFF1A2340),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
