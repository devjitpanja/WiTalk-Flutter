import 'package:flutter/material.dart';

class TimeLimitBottomSheet extends StatelessWidget {
  final VoidCallback onJoinCommunity;

  const TimeLimitBottomSheet({
    super.key,
    required this.onJoinCommunity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 8,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.hourglass_disabled, size: 32, color: Color(0xFFEF4444)),
          ),

          // Header
          const Text(
            "Time's Up!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEBEBF5),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You've used your daily Adda limit.\nYour limit resets at midnight (IST).",
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFFC8D2FF).withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // CTA
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                onJoinCommunity();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0751DF).withOpacity(0.08),
                  border: Border.all(color: const Color(0xFF0751DF).withOpacity(0.22)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0751DF).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0751DF).withOpacity(0.25)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.groups, size: 22, color: Color(0xFF0751DF)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Join a Community Adda',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7AA3F5),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Community addas have no daily time limit',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF7AA3F5).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: const Color(0xFF0751DF).withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dismiss
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC8D2FF).withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTimeLimitBottomSheet({
  required BuildContext context,
  required VoidCallback onJoinCommunity,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => TimeLimitBottomSheet(
      onJoinCommunity: onJoinCommunity,
    ),
  );
}
