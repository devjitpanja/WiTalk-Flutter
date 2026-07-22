import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class RecordingInfoBottomSheet extends StatelessWidget {
  const RecordingInfoBottomSheet({super.key});

  static void show(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const RecordingInfoBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Icon(Icons.fiber_manual_record, color: Color(0xFFFF3B30), size: 44),
            const SizedBox(height: 12),
            Text('This Adda is Being Recorded', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 8),
            Text(
              'The host has enabled session recording. By speaking on stage, you consent to being included in the audio recording.',
              style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit', height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Understood', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
