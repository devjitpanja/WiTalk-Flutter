import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final List<File> _selectedMedia = [];
  bool _posting = false;
  String? _uid;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() { super.initState(); _loadUser(); }
  @override
  void dispose() { _contentCtrl.dispose(); super.dispose(); }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    if (_uid != null) {
      try { final res = await dioClient.get('/v1/user/$_uid'); setState(() => _userProfile = res.data['data']); } catch (_) {}
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _selectedMedia.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _submit() async {
    if (_posting) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _selectedMedia.isEmpty) return;
    setState(() => _posting = true);
    try {
      final payload = {'content': content, 'media_type': _selectedMedia.isEmpty ? 'text' : 'image'};
      await dioClient.post('/v1/posts', data: payload);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _posting = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile?['name'] ?? '';
    final pic = _userProfile?['profile_pic'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
        title: const Text('New Post', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        actions: [TextButton(onPressed: _posting ? null : _submit,
          child: _posting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Post', style: TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _contentCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 16), maxLines: null, autofocus: true,
            decoration: const InputDecoration(hintText: 'What\'s on your mind?', hintStyle: TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit', fontSize: 16), border: InputBorder.none, filled: false))),
        ])),
        if (_selectedMedia.isNotEmpty)
          SizedBox(height: 100, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _selectedMedia.length,
            itemBuilder: (_, i) => Stack(children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedMedia[i], width: 90, height: 90, fit: BoxFit.cover))),
              Positioned(top: 2, right: 10, child: GestureDetector(onTap: () => setState(() => _selectedMedia.removeAt(i)),
                child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
            ]))),
        const Divider(color: AppColors.border),
        ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.textTertiary), title: const Text('Photo/Video', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit')), onTap: _pickMedia),
      ]),
    );
  }
}
