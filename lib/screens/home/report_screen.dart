import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

const _reportReasons = ['Spam', 'Harassment', 'Hate speech', 'Misinformation', 'Violence', 'Nudity', 'Other'];

class ReportScreen extends ConsumerStatefulWidget {
  final String targetType, targetId;
  const ReportScreen({super.key, required this.targetType, required this.targetId});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}
class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _reason;
  final _detailCtrl = TextEditingController();
  bool _submitting = false;
  @override
  void dispose() { _detailCtrl.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await dioClient.post('/v1/report', data: {'type': widget.targetType, 'target_id': widget.targetId, 'reason': _reason, 'details': _detailCtrl.text.trim()});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.'))); context.pop(); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit report')));
    } finally { if (mounted) setState(() => _submitting = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Report', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Why are you reporting this?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
      const SizedBox(height: 16),
      ..._reportReasons.map((r) => RadioListTile<String>(value: r, groupValue: _reason, onChanged: (v) => setState(() => _reason = v), title: Text(r, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')), activeColor: AppColors.primaryButton, contentPadding: EdgeInsets.zero)),
      const SizedBox(height: 16),
      TextField(controller: _detailCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'), maxLines: 4,
        decoration: InputDecoration(hintText: 'Additional details (optional)', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryButton)))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _reason != null ? _submit : null, style: ElevatedButton.styleFrom(backgroundColor: _reason != null ? AppColors.error : AppColors.border, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Submit Report', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16))),
    ])),
  );
}