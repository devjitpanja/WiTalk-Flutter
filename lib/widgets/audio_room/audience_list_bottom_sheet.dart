import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class AudienceListBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> audience;
  final Function(Map<String, dynamic> user)? onUserTap;

  const AudienceListBottomSheet({
    super.key,
    required this.audience,
    this.onUserTap,
  });

  static void show(BuildContext context, {required List<Map<String, dynamic>> audience, Function(Map<String, dynamic> user)? onUserTap}) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AudienceListBottomSheet(audience: audience, onUserTap: onUserTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Audience (${audience.length})', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 12),

            if (audience.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No listeners in the audience yet', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: audience.length,
                itemBuilder: (ctx, i) {
                  final user = audience[i];
                  final name = user['name']?.toString() ?? user['username']?.toString() ?? 'Listener';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.primary.withOpacity(0.2),
                      child: Text(name[0].toUpperCase(), style: TextStyle(color: c.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit')),
                    onTap: () {
                      Navigator.pop(context);
                      onUserTap?.call(user);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
