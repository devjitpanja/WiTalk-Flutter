import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  File? _groupImage;
  List<dynamic> _contacts = [];
  final Set<String> _selectedIds = {};
  bool _loading = true, _creating = false;

  @override
  void initState() { super.initState(); _loadContacts(); }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadContacts() async {
    try {
      final res = await dioClient.get('/v1/chat/contacts');
      setState(() { _contacts = res.data['data'] ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => _groupImage = File(p.path));
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final res = await dioClient.post('/v1/groups/create', data: {
        'name': _nameCtrl.text.trim(),
        'members': _selectedIds.toList(),
      });
      final id = res.data['data']?['id'] as String?;
      if (id != null && mounted) context.pushReplacement('/chat/group/$id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _creating = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('New Group', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      actions: [TextButton(onPressed: _create, child: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create', style: TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)))],
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        GestureDetector(onTap: _pickImage, child: CircleAvatar(radius: 30, backgroundColor: AppColors.surface,
          backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
          child: _groupImage == null ? const Icon(Icons.camera_alt_outlined, color: AppColors.textTertiary, size: 24) : null)),
        const SizedBox(width: 14),
        Expanded(child: TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
          decoration: InputDecoration(hintText: 'Group name', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton))))),
      ])),
      if (_selectedIds.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Align(alignment: Alignment.centerLeft, child: Text('${_selectedIds.length} selected', style: const TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit', fontSize: 13)))),
      const Divider(color: AppColors.border),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (_, i) {
          final c = _contacts[i] as Map<String, dynamic>;
          final name = c['name'] as String? ?? '';
          final pic = c['profile_pic'] as String?;
          final id = c['id'] as String? ?? '';
          final selected = _selectedIds.contains(id);
          return CheckboxListTile(
            value: selected,
            onChanged: (v) => setState(() { if (v == true) _selectedIds.add(id); else _selectedIds.remove(id); }),
            secondary: CircleAvatar(radius: 20, backgroundColor: AppColors.border,
              backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
              child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
            title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            activeColor: AppColors.primaryButton,
            checkColor: Colors.white,
          );
        },
      )),
    ]),
  );
}
