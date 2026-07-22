import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Pixel-perfect Flutter port of RN ParticipantAvatar component.
/// Renders:
///  - Circular avatar with network image or initial letter fallback
///  - Optional avatar frame overlay (when avatarFrameUrl is provided)
///  - Host / Admin star badge next to username
///  - Mic-off overlay/badge when muted
///  - Speaking ring / border glow
///  - Name label below avatar ("Hold to lock" or first name)
class ParticipantAvatar extends StatelessWidget {
  final String? uid;
  final String? name;
  final String? avatarUrl;
  final String? avatarFrameUrl;
  final bool isHost;
  final bool isAdmin;
  final String? communityRole;
  final bool isVerified;
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
    this.avatarFrameUrl,
    this.isHost = false,
    this.isAdmin = false,
    this.communityRole,
    this.isVerified = false,
    this.isMuted = true,
    this.isSpeaking = false,
    this.isSelf = false,
    this.size = 56,
    this.onTap,
    this.showName = true,
  });

  static String? _normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://files.witalk.in$trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = _normalizeUrl(avatarUrl);
    final resolvedFrameUrl = _normalizeUrl(avatarFrameUrl);

    final initial = (name?.isNotEmpty == true
            ? name![0]
            : (uid?.isNotEmpty == true ? uid![0] : '?'))
        .toUpperCase();

    final firstName = isSelf
        ? 'You'
        : (name?.isNotEmpty == true ? name!.split(' ')[0] : (uid ?? 'User'));

    final roleBadgeSize = (size * 0.27).clamp(12.0, 18.0);
    final nameFontSize = (size * 0.20).clamp(9.0, 11.0);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 1.35,
            height: size * 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speaking indicator glowing ring
                if (isSpeaking)
                  Container(
                    width: size + 6,
                    height: size + 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF5B9AFF),
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x665B9AFF),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  )
                else if (isHost)
                  Container(
                    width: size + 4,
                    height: size + 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFA726),
                        width: 2.0,
                      ),
                    ),
                  )
                else
                  Container(
                    width: size + 4,
                    height: size + 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white38,
                        width: 1.5,
                      ),
                    ),
                  ),

                // Avatar image container
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF5A9BD5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: resolvedAvatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildInitialAvatar(initial),
                          placeholder: (_, __) => _buildInitialAvatar(initial),
                        )
                      : _buildInitialAvatar(initial),
                ),

                // Muted overlay icon
                if (isMuted)
                  Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x73000000),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.mic_off,
                      size: (size * 0.28).clamp(12.0, 18.0),
                      color: Colors.white,
                    ),
                  ),

                // Avatar Frame Overlay (if provided)
                if (resolvedFrameUrl != null && resolvedFrameUrl.isNotEmpty)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: resolvedFrameUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),

          if (showName) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star / Role badge next to name
                if (isHost) ...[
                  Container(
                    width: roleBadgeSize,
                    height: roleBadgeSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0751DF),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.stars,
                      size: roleBadgeSize * 0.7,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                ] else if (communityRole == 'super_admin') ...[
                  Container(
                    width: roleBadgeSize,
                    height: roleBadgeSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE84040),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.star,
                      size: roleBadgeSize * 0.7,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                ] else if (communityRole == 'admin' || isAdmin) ...[
                  Container(
                    width: roleBadgeSize,
                    height: roleBadgeSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFA726),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.star,
                      size: roleBadgeSize * 0.7,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],

                // Verified badge icon — only show when no role badge already present
                if (isVerified && !isHost && communityRole != 'super_admin' && communityRole != 'admin' && !isAdmin) ...[
                  const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF0751DF)),
                  const SizedBox(width: 2),
                ],

                // Username text
                Flexible(
                  child: Text(
                    firstName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: nameFontSize,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      color: const Color(0xFF5A9BD5),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
