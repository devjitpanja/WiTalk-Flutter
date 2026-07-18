import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  bool _loading = true;
  String? _myUid;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _myUid = prefs.getString('uid');
    try {
      final res = await dioClient.get('/v1/groups/${widget.groupId}');
      if (mounted) setState(() { _group = res.data['data']; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Leave Group?', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
      content: const Text('You will no longer receive messages from this group.', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave', style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (ok == true) {
      await dioClient.post('/v1/groups/${widget.groupId}/leave');
      if (mounted) { context.pop(); context.pop(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _group?['name'] as String? ?? '';
    final desc = _group?['description'] as String? ?? '';
    final pic = _group?['image'] as String?;
    final members = (_group?['members'] as List? ?? []);
    final isAdmin = _group?['is_admin'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background,
        title: const Text('Group Info', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [if (isAdmin) IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: () {})],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : ListView(children: [
        // Header
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          CircleAvatar(radius: 48, backgroundColor: AppColors.border,
            backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 28)) : null),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(desc, style: const TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center)),
          Text('${members.length} members', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
        ])),
        const Divider(color: AppColors.border),
        // Members
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text('Members', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit', letterSpacing: 0.8))),
        ...members.map((m) {
          final member = m as Map<String, dynamic>;
          final mName = member['name'] as String? ?? '';
          final mPic = member['profile_pic'] as String?;
          final mId = member['id'] as String? ?? '';
          final mRole = member['role'] as String?;
          return ListTile(
            leading: CircleAvatar(radius: 20, backgroundColor: AppColors.border,
              backgroundImage: mPic != null ? CachedNetworkImageProvider(mPic) : null,
              child: mPic == null ? Text(mName.isNotEmpty ? mName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
            title: Text(mName, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            trailing: mRole == 'admin' ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primaryButton.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Text('Admin', style: TextStyle(color: AppColors.primaryButton, fontSize: 11, fontFamily: 'Outfit'))) : null,
            onTap: () => context.push('/user/$mId'),
          );
        }),
        const Divider(color: AppColors.border),
        ListTile(leading: const Icon(Icons.exit_to_app, color: AppColors.error), title: const Text('Leave Group', style: TextStyle(color: AppColors.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), onTap: _leave),
        const SizedBox(height: 20),
      ]),
    );
  }
}
