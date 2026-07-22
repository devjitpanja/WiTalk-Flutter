import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';

class NotMemberBottomSheet extends StatelessWidget {
  final String groupName;
  final String? groupPicture;
  final bool passRequired;
  final String? inviteCode;

  const NotMemberBottomSheet({
    super.key,
    required this.groupName,
    this.groupPicture,
    this.passRequired = false,
    this.inviteCode,
  });

  static void show(
    BuildContext context, {
    required String groupName,
    String? groupPicture,
    bool passRequired = false,
    String? inviteCode,
  }) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => NotMemberBottomSheet(
        groupName: groupName,
        groupPicture: groupPicture,
        passRequired: passRequired,
        inviteCode: inviteCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Handle indicator
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: c.textTertiary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Group Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.secondaryButton,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: groupPicture != null && groupPicture!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: groupPicture!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(Icons.group, size: 32, color: c.textTertiary),
                      )
                    : Icon(Icons.group, size: 32, color: c.textTertiary),
              ),
            ),
            const SizedBox(height: 16),

            // Group Name
            Text(
              groupName.isNotEmpty ? groupName : 'Community',
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              "You're not a member of this community.\nJoin the community to listen in on their adda.",
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                fontFamily: 'Outfit',
                height: 1.43,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            if (inviteCode != null && inviteCode!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/community-info/$inviteCode');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Community',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: c.secondaryButton,
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
