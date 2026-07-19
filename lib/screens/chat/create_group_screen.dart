import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';
import '../../services/upload_service.dart';

// Mirrors CreateGroupScreen.jsx
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() =>
      _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _groupImage;
  String? _uploadedImageUrl;
  List<Map<String, dynamic>> _contacts = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _creating = false;
  bool _isPublic = false;
  bool _uploadingImage = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final res = await dioClient.get(AppEndpoints.chatContacts);
      final data = res.data['data'];
      if (data is List) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _groupImage = File(picked.path);
      _uploadingImage = true;
    });
    try {
      final svc = UploadService();
      final result = await svc.uploadFile(_groupImage!, 'image');
      setState(() => _uploadedImageUrl = result['url'] as String?);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _creating) return;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please select at least one member')));
      return;
    }

    setState(() => _creating = true);
    try {
      final res = await chatApiService.createGroup(
        name: name,
        description: _descCtrl.text.trim(),
        memberIds: _selectedIds.toList(),
        imageUrl: _uploadedImageUrl,
        isPublic: _isPublic,
      );
      final data = res['data'] as Map<String, dynamic>?;
      final id = data?['id'] as String?;
      if (id != null && mounted) {
        context.pushReplacement('/chat/group/$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create group: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      final name =
          (c['name'] ?? c['username'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _filteredContacts;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text('New Group',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _create,
            child: _creating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.primary))
                : Text('Create',
                    style: TextStyle(
                        color: _nameCtrl.text.isNotEmpty
                            ? c.primary
                            : c.textTertiary,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
          ),
        ],
      ),
      body: Column(children: [
        // Group info section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: c.surface,
                  backgroundImage: _groupImage != null
                      ? FileImage(_groupImage!)
                      : null,
                  child: _groupImage == null
                      ? Icon(Icons.camera_alt_outlined,
                          color: c.textTertiary, size: 24)
                      : null,
                ),
                if (_uploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(
                      color: c.text, fontFamily: 'Outfit'),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    hintStyle: TextStyle(
                        color: c.textTertiary,
                        fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.primary)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  style: TextStyle(
                      color: c.text, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(
                        color: c.textTertiary,
                        fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: c.primary)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        // Public toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.public, size: 20, color: c.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Public Group',
                  style: TextStyle(
                      color: c.text,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500)),
            ),
            Switch(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              activeColor: c.primary,
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: c.text, fontFamily: 'Outfit'),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: TextStyle(
                  color: c.textTertiary, fontFamily: 'Outfit'),
              prefixIcon:
                  Icon(Icons.search, color: c.textSecondary),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Selected count
        if (_selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_selectedIds.length} selected',
                  style: TextStyle(
                      color: c.primary,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        Divider(height: 1, color: c.border),
        // Contacts list
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                      color: c.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Text('No contacts found',
                          style: TextStyle(
                              color: c.textTertiary,
                              fontFamily: 'Outfit')))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemExtent: 72,
                      itemBuilder: (ctx, i) {
                        final contact = filtered[i];
                        final name = contact['name'] ??
                            contact['username'] ??
                            '';
                        final pic = contact['profile_pic'];
                        final id =
                            (contact['id'] ?? '').toString();
                        final selected =
                            _selectedIds.contains(id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          }),
                          secondary: CircleAvatar(
                            radius: 20,
                            backgroundColor: c.surface,
                            backgroundImage: pic != null
                                ? CachedNetworkImageProvider(pic)
                                : null,
                            child: pic == null
                                ? Text(
                                    (name.isNotEmpty
                                            ? name[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: TextStyle(
                                        color: c.text,
                                        fontSize: 12,
                                        fontFamily: 'Outfit'))
                                : null,
                          ),
                          title: Text(name.toString(),
                              style: TextStyle(
                                  color: c.text,
                                  fontFamily: 'Outfit',
                                  fontWeight:
                                      FontWeight.w500)),
                          activeColor: c.primary,
                          checkColor: Colors.white,
                          side: BorderSide(color: c.border),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

final chatApiService = ChatApiService();

class UploadService {
  Future<Map<String, dynamic>> uploadFile(
      File file, String type) async {
    final res = await dioClient.post(
      AppEndpoints.filesUploadUrl,
      data: {'type': type, 'file': file.path},
    );
    return res.data as Map<String, dynamic>;
  }
}
