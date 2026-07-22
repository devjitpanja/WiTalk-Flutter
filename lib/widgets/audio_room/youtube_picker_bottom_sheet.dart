import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class YouTubePickerBottomSheet extends StatefulWidget {
  final Function(String videoId) onSelectVideo;

  const YouTubePickerBottomSheet({super.key, required this.onSelectVideo});

  static void show(BuildContext context, {required Function(String videoId) onSelectVideo}) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: YouTubePickerBottomSheet(onSelectVideo: onSelectVideo),
      ),
    );
  }

  @override
  State<YouTubePickerBottomSheet> createState() => _YouTubePickerBottomSheetState();
}

class _YouTubePickerBottomSheetState extends State<YouTubePickerBottomSheet> {
  final _urlCtrl = TextEditingController();

  String? _extractVideoId(String input) {
    if (input.length == 11) return input;
    final reg = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})');
    final match = reg.firstMatch(input);
    return match?.group(1);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 24),
                const SizedBox(width: 8),
                Text('Play YouTube Video in Adda', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _urlCtrl,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Paste YouTube link or video ID...',
                hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  final videoId = _extractVideoId(_urlCtrl.text.trim());
                  if (videoId != null && videoId.isNotEmpty) {
                    Navigator.pop(context);
                    widget.onSelectVideo(videoId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid YouTube URL or Video ID')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Start Playback', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
