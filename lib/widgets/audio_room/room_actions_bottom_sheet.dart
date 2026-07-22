import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class RoomActionsBottomSheet extends StatelessWidget {
  final VoidCallback onMuteToggle;
  final VoidCallback onLeaveStage;

  const RoomActionsBottomSheet({
    super.key,
    required this.onMuteToggle,
    required this.onLeaveStage,
  });

  static void show(BuildContext context, {required VoidCallback onMuteToggle, required VoidCallback onLeaveStage}) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => RoomActionsBottomSheet(onMuteToggle: onMuteToggle, onLeaveStage: onLeaveStage),
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
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.mic, color: Color(0xFF007AFF)),
              title: Text('Toggle Microphone', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
              onTap: () { Navigator.pop(context); onMuteToggle(); },
            ),
            ListTile(
              leading: const Icon(Icons.south, color: Colors.orange),
              title: Text('Step Down to Audience', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
              onTap: () { Navigator.pop(context); onLeaveStage(); },
            ),
          ],
        ),
      ),
    );
  }
}
