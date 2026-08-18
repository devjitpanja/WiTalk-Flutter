import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

/// Returns true if mic permission is granted (or was just granted).
/// Shows a settings dialog if permanently denied.
Future<bool> checkMicPermission(BuildContext context) async {
  final status = await Permission.microphone.status;
  if (status.isGranted) return true;

  if (status.isDenied || status.isLimited) {
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  if (status.isPermanentlyDenied) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Microphone Access Required'),
          content: const Text(
            'Please enable microphone access in your device settings to join an audio room.',
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  return false;
}
