import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Singleton privacy notice shown when a screenshot is detected (iOS only).
///
/// Android cannot fire this — FLAG_SECURE blocks captures at the OS level so no
/// event is ever emitted.  On iOS we cannot block the capture, so we show this
/// sheet to inform the user that screenshots are against community guidelines.
///
/// Usage:
///   ScreenshotPrivacySheet.show(context);
class ScreenshotPrivacySheet {
  const ScreenshotPrivacySheet._();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const _PrivacySheetContent(),
    );
  }
}

class _PrivacySheetContent extends StatelessWidget {
  const _PrivacySheetContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          // Purple shield icon
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 38,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Privacy is Protected',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'WiTalk is a safe and healthy community built on trust. '
            'To protect every member\'s privacy, screenshots and screen '
            'recordings are not allowed inside the app. Every moment shared '
            'here belongs to the people in it — not to screenshots.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              height: 1.55,
              fontFamily: 'Outfit',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF6B6B)),
                SizedBox(width: 6),
                Text(
                  'WiTalk — Respect · Privacy · Community',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
