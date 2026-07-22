import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Matches the RN VerificationBadge behaviour exactly.
///
/// - If [badge] is provided, uses badge.color and badge.icon_url.
/// - icon_url starting with 'https://' → remote image with tintColor.
/// - icon_url NOT starting with 'https://' → treated as a Material icon name.
/// - If no icon_url, falls back to the Material 'verified' icon.
/// - Returns SizedBox.shrink() when [isVerified] is false.
class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final Map<String, dynamic>? badge;
  final double size;

  const VerificationBadge({
    super.key,
    this.isVerified = false,
    this.badge,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    const defaultColor = Color(0xFF0751DF);

    final badgeColor = badge != null && badge!['color'] != null
        ? _parseColor(badge!['color'] as String, defaultColor)
        : defaultColor;

    final iconUrl = badge?['icon_url'] as String?;
    final isImageUrl     = iconUrl != null && iconUrl.startsWith('https://');
    final isMaterialIcon = iconUrl != null && !iconUrl.startsWith('http');

    if (isImageUrl) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        width: size,
        height: size,
        color: badgeColor,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        errorWidget: (context, url, error) =>
            Icon(Icons.verified, color: badgeColor, size: size),
      );
    }

    if (isMaterialIcon) {
      final iconData = _materialIconFromName(iconUrl);
      return Icon(iconData, color: badgeColor, size: size);
    }

    return Icon(Icons.verified, color: badgeColor, size: size);
  }

  static Color _parseColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Map the most common Material icon names used in verification badges.
  static IconData _materialIconFromName(String name) {
    switch (name) {
      case 'verified':          return Icons.verified;
      case 'verified_user':     return Icons.verified_user;
      case 'star':              return Icons.star;
      case 'check_circle':      return Icons.check_circle;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'military_tech':     return Icons.military_tech;
      default:                  return Icons.verified;
    }
  }
}
