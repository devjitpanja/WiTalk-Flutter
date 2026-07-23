import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sound_wave_indicator.dart';
import '../common/verification_badge.dart';

/// Seat avatar for the audio room grid.
///
/// Speaking styles:
///  • No frame  → animated water-drop ripple rings around the circle
///  • Has frame → wave bars appear at the bottom edge of the frame
///
/// Verification badge (if isVerified): green circle at 225° (bottom-left)
/// of the avatar circle, overlapping the edge.
class ParticipantAvatar extends StatelessWidget {
  final String? uid;
  final String? name;
  final String? avatarUrl;
  final String? avatarFrameUrl;
  final bool isHost;
  final bool isAdmin;
  final String? communityRole;
  final bool isVerified;
  final Map<String, dynamic>? verificationBadge;
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
    this.verificationBadge,
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

    // Badge sits on the avatar circle edge at 225° (bottom-left).
    // Avatar circle center in Stack coords: (outerSize/2, outerSize/2)
    // At 225°: dx = dy = -size/2 * sin(45°) ≈ -0.3536 * size
    // Badge center in stack:
    //   left  = outerSize/2 + dx = size*0.75 - 0.3536*size*0.5 = ~0.573*size
    //   bottom = outerSize/2 + dy (same)
    // Positioned(left/bottom) = badgeCenter - badgeSize/2
    final badgeSize = (size * 0.30).clamp(14.0, 20.0);
    final badgeCenterFromEdge = size * 0.573;
    final badgeOffset = badgeCenterFromEdge - badgeSize / 2;

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
                // ── Speaking ripple / border (only when NO frame) ─────────────
                if (isSpeaking && !hasFrame)
                  _WaterDropRipple(size: size)
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

                // ── Avatar circle ─────────────────────────────────────────────
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

                // ── Muted overlay ─────────────────────────────────────────────
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

                // ── Frame overlay (above avatar) ──────────────────────────────
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

                // ── Verification badge at 225° (bottom-left of avatar circle) ─
                if (isVerified)
                  Positioned(
                    left: badgeOffset,
                    bottom: badgeOffset,
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D1017),
                      ),
                      alignment: Alignment.center,
                      child: VerificationBadge(
                        isVerified: true,
                        badge: verificationBadge,
                        size: badgeSize * 0.85,
                      ),
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

// ── Water-drop ripple speaking indicator (no-frame users) ────────────────────
// Three staggered concentric rings that expand outward and fade, like a
// water drop ripple effect.
class _WaterDropRipple extends StatefulWidget {
  final double size;
  const _WaterDropRipple({required this.size});

  @override
  State<_WaterDropRipple> createState() => _WaterDropRippleState();
}

class _WaterDropRippleState extends State<_WaterDropRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Canvas size needs to accommodate the ripple spread beyond the avatar
    final canvasSize = widget.size * 1.8;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(canvasSize, canvasSize),
        painter: _RipplePainter(
          progress: _ctrl.value,
          avatarRadius: widget.size / 2,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final double avatarRadius;

  const _RipplePainter({required this.progress, required this.avatarRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const waves = 3;
    // Maximum distance a wave travels beyond the avatar edge
    final spread = avatarRadius * 0.5;

    for (int i = 0; i < waves; i++) {
      // Stagger each wave by 1/waves of the cycle
      double t = (progress - i / waves) % 1.0;
      if (t < 0) t += 1.0;

      final r = avatarRadius + 2 + t * spread;
      final opacity = (1.0 - t) * 0.65;

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFF5B9AFF).withValues(alpha: opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
