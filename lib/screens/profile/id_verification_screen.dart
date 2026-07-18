import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IdVerificationScreen extends ConsumerStatefulWidget {
  const IdVerificationScreen({super.key});
  @override
  ConsumerState<IdVerificationScreen> createState() => _IdVerificationScreenState();
}
class _IdVerificationScreenState extends ConsumerState<IdVerificationScreen> {
  File? _idPhoto, _selfiePhoto;
  bool _submitting = false;
  String? _status;

  @override
  void initState() { super.initState(); _loadStatus(); }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance(); final uid = prefs.getString('uid');
    try { final res = await dioClient.get('/v1/user/\$uid/verification-status'); if (mounted) setState(() => _status = res.data['data']?['status']); } catch (_) {}
  }

  Future<void> _pick(bool isId) async {
    final p = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (p != null && mounted) setState(() { if (isId) _idPhoto = File(p.path); else _selfiePhoto = File(p.path); });
  }

  Future<void> _submit() async {
    if (_idPhoto == null || _selfiePhoto == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await dioClient.post('/v1/user/verify-id', data: {'id_photo': _idPhoto!.path, 'selfie': _selfiePhoto!.path});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification submitted for review'))); setState(() => _status = 'pending'); }
    } catch (_) {} finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, title: const Text('ID Verification', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_status == 'verified') Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success)), child: const Row(children: [Icon(Icons.verified, color: AppColors.success), SizedBox(width: 8), Text('Your account is verified!', style: TextStyle(color: AppColors.success, fontFamily: 'Outfit', fontWeight: FontWeight.w600))])),
      if (_status == 'pending') Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning)), child: const Row(children: [Icon(Icons.hourglass_empty, color: AppColors.warning), SizedBox(width: 8), Text('Verification under review', style: TextStyle(color: AppColors.warning, fontFamily: 'Outfit', fontWeight: FontWeight.w600))])),
      if (_status == null || _status == 'rejected') ...[
        const Text('Verify your identity', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        const Text('Upload a government ID and a selfie to get verified', style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit')),
        const SizedBox(height: 28),
        _photoUpload('Government ID', _idPhoto, () => _pick(true)),
        const SizedBox(height: 16),
        _photoUpload('Selfie Photo', _selfiePhoto, () => _pick(false)),
        const SizedBox(height: 28),
        ElevatedButton(onPressed: _idPhoto != null && _selfiePhoto != null ? _submit : null, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Submit for Verification', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16))),
      ],
    ])),
  );

  Widget _photoUpload(String label, File? file, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(height: 120, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, style: file == null ? BorderStyle.none : BorderStyle.solid)),
      child: file != null ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(file, fit: BoxFit.cover, width: double.infinity))
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_outlined, color: AppColors.textTertiary, size: 32), const SizedBox(height: 8), Text(label, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit'))])),
  );
}