import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});
  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _image;
  bool _creating = false;

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => _image = File(p.path));
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final res = await dioClient.post('/v1/channels/create', data: {'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim()});
      final id = res.data['data']?['id'] as String?;
      if (id != null && mounted) { context.pop(); context.push('/channel/$id'); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _creating = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('New Channel', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
      actions: [TextButton(onPressed: _create, child: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create', style: TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)))],
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      GestureDetector(onTap: _pickImage, child: CircleAvatar(radius: 44, backgroundColor: AppColors.surface,
        backgroundImage: _image != null ? FileImage(_image!) : null,
        child: _image == null ? const Icon(Icons.camera_alt_outlined, color: AppColors.textTertiary, size: 28) : null)),
      const SizedBox(height: 24),
      _field(_nameCtrl, 'Channel Name *', Icons.campaign_outlined),
      const SizedBox(height: 16),
      _field(_descCtrl, 'Description (optional)', Icons.info_outline, maxLines: 3),
    ])),
  );

  Widget _field(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) => TextField(
    controller: c, maxLines: maxLines,
    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20), filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border))),
  );
}
