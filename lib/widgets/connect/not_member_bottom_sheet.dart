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
    final c = Theme.of(context).extension<ThemeColors>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: c.border,
              backgroundImage: groupPicture != null && groupPicture!.isNotEmpty
                  ? CachedNetworkImageProvider(groupPicture!)
                  : null,
              child: groupPicture == null || groupPicture!.isEmpty
                  ? Text(
                      groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                      style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              groupName,
              style: TextStyle(
                color: c.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are not a member of this community. Join the community to participate in live addas.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            if (passRequired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade700, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.amber.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Pass Required',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (inviteCode != null && inviteCode!.isNotEmpty) {
                    context.push('/community-info/$inviteCode');
                  } else {
                    context.push('/explore-communities');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Join Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
