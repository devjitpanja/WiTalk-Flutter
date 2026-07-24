import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sound_wave_indicator.dart';
import '../common/verification_badge.dart';

/// Premium redesigned seat avatar for the audio room grid.
///
/// Visual improvements:
///  • Muted: small red badge at bottom-right instead of full dark overlay
///  • Speaking: vibrant ripple rings with host-aware color (gold vs sky-blue)
///  • Host ring: gold glow border (static) or gold ripple (speaking)
///  • Name: color-coded by role, single Text (no Row+Flexible overflow)
///  • Avatar background: subtle gradient instead of flat blue
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

    const double outerMult = 1.5;
    final outerSize = size * outerMult;
    final nameFontSize = (size * 0.20).clamp(9.0, 11.0);

    // Mic badge: positioned symmetrically to verification badge (315° vs 225°)
    // Both badges use size * 0.573 as the center distance from stack edge
    final micBadgeSize = (size * 0.28).clamp(12.0, 18.0);
    final micBadgeCenterDist = size * 0.573;
    final micBadgeOffset = micBadgeCenterDist - micBadgeSize / 2;

    // Verification badge (225° bottom-left) — same formula as before
    final verBadgeSize = (size * 0.30).clamp(14.0, 20.0);
    final verBadgeCenterDist = size * 0.573;
    final verBadgeOffset = verBadgeCenterDist - verBadgeSize / 2;

    // Role-based name color
    final Color nameColor;
    if (isHost) {
      nameColor = const Color(0xFFFFB700);
    } else if (communityRole == 'super_admin') {
      nameColor = const Color(0xFFE84040);
    } else if (communityRole == 'admin' || isAdmin) {
      nameColor = const Color(0xFFFFA726);
    } else {
      nameColor = const Color(0xFFDDE3F0);
    }

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
                // ── Speaking ripple / host ring / default border ───────────────
                if (isSpeaking && !hasFrame)
                  _PremiumRipple(size: size, isHost: isHost)
                else if (!hasFrame && isHost)
                  Container(
                    width: size + 6,
                    height: size + 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB700),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB700).withValues(alpha: 0.30),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                else if (!hasFrame)
                  Container(
                    width: size + 4,
                    height: size + 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                  ),

                // ── Avatar circle with gradient background ────────────────────
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D4A7A), Color(0xFF1A3050)],
                    ),
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

                // ── Frame overlay (above avatar) ──────────────────────────────
                if (hasFrame) ...[
                  if (isSpeaking) _PremiumRipple(size: size, isHost: isHost),
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: resolvedFrameUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                // ── Wave bars for framed speaking (bottom edge) ───────────────
                if (isSpeaking && hasFrame)
                  Positioned(
                    bottom: 0,
                    child: SoundWaveIndicator(
                      isSpeaking: true,
                      color: const Color(0xFF38BDF8),
                      barCount: 4,
                      barWidth: 2.5,
                      minHeight: 4,
                      maxHeight: 10,
                    ),
                  ),

                // ── Muted badge at bottom-right (315°) ───────────────────────
                if (isMuted)
                  Positioned(
                    right: micBadgeOffset,
                    bottom: micBadgeOffset,
                    child: Container(
                      width: micBadgeSize,
                      height: micBadgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444),
                        border: Border.all(
                          color: const Color(0xFF090D18),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.mic_off_rounded,
                        size: micBadgeSize * 0.55,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // ── Verification badge at 225° (bottom-left) ─────────────────
                if (isVerified)
                  Positioned(
                    left: verBadgeOffset,
                    bottom: verBadgeOffset,
                    child: Container(
                      width: verBadgeSize,
                      height: verBadgeSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF090D18),
                      ),
                      alignment: Alignment.center,
                      child: VerificationBadge(
                        isVerified: true,
                        badge: verificationBadge,
                        size: verBadgeSize * 0.85,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Name label (single Text — no overflow) ────────────────────────
          if (showName) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: outerSize,
              child: Text(
                firstName,
                style: TextStyle(
                  color: nameColor,
                  fontSize: nameFontSize,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  shadows: isHost
                      ? [
                          Shadow(
                            color: const Color(0xFFFFB700).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
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
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Premium speaking ripple with host-aware color ─────────────────────────────
class _PremiumRipple extends StatefulWidget {
  final double size;
  final bool isHost;
  const _PremiumRipple({required this.size, this.isHost = false});

  @override
  State<_PremiumRipple> createState() => _PremiumRippleState();
}

class _PremiumRippleState extends State<_PremiumRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = widget.size * 1.9;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(canvasSize, canvasSize),
        painter: _RipplePainter(
          progress: _ctrl.value,
          avatarRadius: widget.size / 2,
          isHost: widget.isHost,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final double avatarRadius;
  final bool isHost;

  const _RipplePainter({
    required this.progress,
    required this.avatarRadius,
    required this.isHost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const waves = 3;
    final spread = avatarRadius * 0.65;
    final baseColor =
        isHost ? const Color(0xFFFFB700) : const Color(0xFF38BDF8);

    for (int i = 0; i < waves; i++) {
      double t = (progress - i / waves) % 1.0;
      if (t < 0) t += 1.0;

      final r = avatarRadius + 2 + t * spread;
      final opacity = (1.0 - t) * 0.80;

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = baseColor.withValues(alpha: opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.isHost != isHost;
}
