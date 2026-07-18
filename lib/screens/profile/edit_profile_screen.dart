import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _newPic;
  String? _existingPic;
  bool _saving = false;
  String? _uid;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _nameCtrl.dispose(); _usernameCtrl.dispose(); _bioCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    if (_uid == null) return;
    final res = await dioClient.get('/v1/user/$_uid');
    final d = res.data['data'] ?? {};
    setState(() { _nameCtrl.text = d['name'] ?? ''; _usernameCtrl.text = d['username'] ?? ''; _bioCtrl.text = d['bio'] ?? ''; _existingPic = d['profile_pic']; });
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p == null) return;
    final c = await ImageCropper().cropImage(sourcePath: p.path, aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), uiSettings: [AndroidUiSettings(toolbarTitle: 'Crop', toolbarColor: AppColors.background, toolbarWidgetColor: Colors.white, lockAspectRatio: true), IOSUiSettings(title: 'Crop', aspectRatioLockEnabled: true)]);
    if (c != null && mounted) setState(() => _newPic = File(c.path));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      String? picUrl;
      if (_newPic != null) {
        final fd = await dioClient.post('/v1/upload/profile-pic', data: {'file': _newPic!.path});
        picUrl = fd.data['url'];
      }
      await dioClient.put('/v1/user/$_uid/profile', data: {'name': _nameCtrl.text.trim(), 'username': _usernameCtrl.text.trim().toLowerCase(), 'bio': _bioCtrl.text.trim(), if (picUrl != null) 'profile_pic': picUrl});
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        GestureDetector(onTap: _pickImage, child: Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(radius: 50, backgroundColor: AppColors.border, backgroundImage: _newPic != null ? FileImage(_newPic!) as ImageProvider : (_existingPic != null ? CachedNetworkImageProvider(_existingPic!) : null)),
          Container(width: 30, height: 30, decoration: const BoxDecoration(color: AppColors.primaryButton, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16)),
        ])),
        const SizedBox(height: 28),
        _field(_nameCtrl, 'Full Name', Icons.person_outline),
        const SizedBox(height: 14),
        _field(_usernameCtrl, 'Username', Icons.alternate_email),
        const SizedBox(height: 14),
        TextField(controller: _bioCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'), maxLines: 3, maxLength: 150,
          decoration: InputDecoration(hintText: 'Bio', prefixIcon: const Icon(Icons.edit_note_outlined, color: AppColors.textTertiary), filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), counterStyle: const TextStyle(color: AppColors.textTertiary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton)))),
      ])),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) => TextField(controller: c, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.textTertiary), filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton))));
}
