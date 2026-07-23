import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sound_wave_indicator.dart';

/// Seat avatar for the audio room grid.
///
/// Speaking styles:
///  • No frame  → animated glowing ring around the circle
///  • Has frame → no ring (would clash with frame art); animated wave bars
///               appear at the bottom edge of the frame instead
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
    final hasFrame = resolvedFrameUrl != null && resolvedFrameUrl.isNotEmpty;

    final initial = (name?.isNotEmpty == true
            ? name![0]
            : (uid?.isNotEmpty == true ? uid![0] : '?'))
        .toUpperCase();

    final firstName = isSelf
        ? 'You'
        : (name?.isNotEmpty == true ? name!.split(' ')[0] : (uid ?? 'User'));

    final roleBadgeSize = (size * 0.27).clamp(12.0, 18.0);
    final nameFontSize = (size * 0.20).clamp(9.0, 11.0);

    // Always use size * 1.5 so every seat cell is the same height regardless
    // of whether a frame is present. The ring is drawn inside this box for
    // non-framed avatars; the frame image fills it for framed avatars.
    const double outerMult = 1.5;
    final outerSize = size * outerMult;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: outerSize,
            height: outerSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ── Speaking ring (only when NO frame) ──────────────────────
                if (isSpeaking && !hasFrame)
                  _SpeakingRing(size: size)
                else if (!hasFrame && isHost)
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
                else if (!hasFrame)
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

                // ── Avatar circle ────────────────────────────────────────────
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

                // ── Muted overlay ────────────────────────────────────────────
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

                // ── Frame overlay (above avatar, clips to SizedBox) ──────────
                if (hasFrame)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: resolvedFrameUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                // ── Wave bars for framed speaking (bottom edge) ───────────────
                if (isSpeaking && hasFrame)
                  Positioned(
                    bottom: 0,
                    child: SoundWaveIndicator(
                      isSpeaking: true,
                      color: const Color(0xFF5B9AFF),
                      barCount: 4,
                      barWidth: 2.5,
                      minHeight: 4,
                      maxHeight: 10,
                    ),
                  ),
              ],
            ),
          ),

          if (showName) ...[
            const SizedBox(height: 3),
            SizedBox(
              width: outerSize,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      child: Icon(Icons.star, size: roleBadgeSize * 0.7, color: Colors.white),
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
                      child: Icon(Icons.star, size: roleBadgeSize * 0.7, color: Colors.white),
                    ),
                    const SizedBox(width: 3),
                  ],

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

                  if (isVerified && !isHost && communityRole != 'super_admin' && communityRole != 'admin' && !isAdmin) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF0751DF)),
                  ],
                ],
              ),
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

// ── Animated glowing ring (no-frame speaking indicator) ─────────────────────
class _SpeakingRing extends StatefulWidget {
  final double size;
  const _SpeakingRing({required this.size});

  @override
  State<_SpeakingRing> createState() => _SpeakingRingState();
}

class _SpeakingRingState extends State<_SpeakingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Container(
        width: (widget.size + 6) * _scale.value,
        height: (widget.size + 6) * _scale.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF5B9AFF),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x665B9AFF),
              blurRadius: 6 + 4 * _ctrl.value,
              spreadRadius: 1 + 2 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}
