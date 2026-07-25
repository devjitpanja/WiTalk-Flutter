import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sound_wave_indicator.dart';
import '../common/verification_badge.dart';

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

    // roleBadgeSize: scales with avatar, matches RN: max(12, size * 0.27)
    final double roleBadgeSize = (size * 0.27).clamp(12.0, 18.0);

    // outerSize: frame needs extra room; no-frame just needs ripple space
    const double outerMult = 1.5;
    final outerSize = size * outerMult;
    final nameFontSize = (size * 0.20).clamp(9.0, 11.0);

    final verBadgeSize = (size * 0.30).clamp(14.0, 20.0);
    final verBadgeRight = (size * 0.30 - verBadgeSize / 2).clamp(-verBadgeSize * 0.4, size * 0.25);

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

    // Whether any role badge will be shown (shifts name container left to re-center)
    final bool showRoleBadge = isHost ||
        (communityRole == 'super_admin') ||
        (communityRole == 'admin') ||
        isAdmin;

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
                // ── Speaking ripple rings (always behind everything) ──────────
                // Rendered for BOTH framed and non-framed users.
                // For non-framed users this produces the "water-drop" concentric
                // ring effect that matches the RN SoundWaveIndicator ripple.
                if (isSpeaking)
                  _PremiumRipple(size: size, isHost: isHost),

                // ── White border — always visible ────────────────────────────
                // Stays on top of the ripple, below the avatar clip.
                // Matches RN: white 3px circle around the profile picture at all
                // times; the speaking animation overlays it without replacing it.
                Container(
                  width: size + 6,
                  height: size + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHost && !hasFrame
                          ? const Color(0xFFFFB700)
                          : Colors.white,
                      width: isSpeaking && !hasFrame ? 2.5 : 2.0,
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
                if (hasFrame)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: resolvedFrameUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                // ── Wave bars for framed speaking (centered over avatar) ──────
                // RN positions these absolutely in the center of the frame, with
                // zIndex: 20 — rendered above the frame artwork.
                if (isSpeaking && hasFrame)
                  SoundWaveIndicator(
                    isSpeaking: true,
                    color: Colors.white.withValues(alpha: 0.95),
                    barCount: 5,
                    barWidth: 2.0,
                    minHeight: (size * 0.08).clamp(4.0, 8.0),
                    maxHeight: (size * 0.18).clamp(8.0, 14.0),
                  ),

                // ── Muted overlay + mic-off icon ─────────────────────────────
                if (isMuted) ...[
                  Positioned(
                    left: (outerSize - size) / 2,
                    top: (outerSize - size) / 2,
                    child: ClipOval(
                      child: Container(
                        width: size,
                        height: size,
                        color: Colors.black.withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.mic_off_rounded,
                    size: size * 0.38,
                    color: Colors.white,
                  ),
                ],

                // ── Verification badge: bottom-right ─────────────────────────
                if (isVerified && !hasFrame)
                  Positioned(
                    right: verBadgeRight,
                    bottom: (outerSize - size) / 2 + verBadgeSize * 0.20,
                    child: Container(
                      width: verBadgeSize,
                      height: verBadgeSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
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

          // ── Name + host badge row ─────────────────────────────────────────
          if (showName) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: outerSize,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Role badge (host / community owner / admin)
                  if (showRoleBadge) ...[
                    _RoleBadge(
                      size: roleBadgeSize,
                      isHost: isHost,
                      communityRole: communityRole,
                      isAdmin: isAdmin,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
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

// ── Role badge: blue circle with icon, matches RN ─────────────────────────────
class _RoleBadge extends StatelessWidget {
  final double size;
  final bool isHost;
  final String? communityRole;
  final bool isAdmin;

  const _RoleBadge({
    required this.size,
    required this.isHost,
    this.communityRole,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final IconData icon;

    if (isHost) {
      bgColor = const Color(0xFF0751DF);
      icon = Icons.stars_rounded;
    } else if (communityRole == 'super_admin') {
      bgColor = const Color(0xFFDC2626);
      icon = Icons.star_rounded;
    } else if (communityRole == 'admin') {
      bgColor = const Color(0xFFCA8A04);
      icon = Icons.star_rounded;
    } else {
      // regular adda admin
      bgColor = const Color(0xFF0A84FF);
      icon = Icons.person_rounded;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.65,
        color: Colors.white,
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
        isHost ? const Color(0xFFFFB700) : const Color(0xFFFFFFFF);

    for (int i = 0; i < waves; i++) {
      double t = (progress - i / waves) % 1.0;
      if (t < 0) t += 1.0;

      final r = avatarRadius + 4 + t * spread;
      final opacity = (1.0 - t) * 0.70;

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
