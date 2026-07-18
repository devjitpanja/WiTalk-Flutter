import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  final String targetId;
  const WriteReviewScreen({super.key, required this.targetId});
  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}
class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  int _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;
  @override
  void dispose() { _reviewCtrl.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await dioClient.post('/v1/reviews', data: {'target_id': widget.targetId, 'rating': _rating, 'review': _reviewCtrl.text.trim()});
      if (mounted) context.pop();
    } catch (_) {} finally { if (mounted) setState(() => _submitting = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Write Review', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rate your experience', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
      const SizedBox(height: 16),
      Row(children: List.generate(5, (i) => GestureDetector(onTap: () => setState(() => _rating = i + 1), child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(i < _rating ? Icons.star : Icons.star_border, color: const Color(0xFFFFC107), size: 36))))),
      const SizedBox(height: 24),
      TextField(controller: _reviewCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'), maxLines: 5,
        decoration: InputDecoration(hintText: 'Share your experience...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryButton)))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _rating > 0 ? _submit : null, style: ElevatedButton.styleFrom(backgroundColor: _rating > 0 ? AppColors.primaryButton : AppColors.border, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Submit Review', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16))),
    ])),
  );
}