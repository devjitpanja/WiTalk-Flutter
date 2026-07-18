import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

class CommunityInfoScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityInfoScreen({super.key, required this.communityId});
  @override
  ConsumerState<CommunityInfoScreen> createState() => _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends ConsumerState<CommunityInfoScreen> {
  Map<String, dynamic>? _community;
  bool _loading = true;
  bool _isMember = false;
  bool _toggling = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = ref.read(authProvider).uid ?? '';
    try {
      final res = await dioClient.get('/v1/groups/${widget.communityId}', queryParameters: {'userId': uid});
      setState(() { _community = res.data['data']; _isMember = res.data['data']?['is_member'] == true; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _toggleMember() async {
    if (_toggling) return;
    final uid = ref.read(authProvider).uid ?? '';
    setState(() => _toggling = true);
    try {
      if (_isMember) {
        await dioClient.post('/v1/groups/${widget.communityId}/leave', data: {'user_id': uid});
      } else {
        await dioClient.post('/v1/groups/join', data: {'invite_code': widget.communityId, 'user_id': uid});
      }
      setState(() => _isMember = !_isMember);
    } catch (_) {} finally { if (mounted) setState(() => _toggling = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = _community?['name'] as String? ?? '';
    final desc = _community?['description'] as String? ?? '';
    final pic = _community?['image'] as String?;
    final members = _community?['member_count'] ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Community', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 50, backgroundColor: AppColors.border,
          backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
          child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 32)) : null),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        const SizedBox(height: 6),
        Text('$members members', style: const TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
        if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontFamily: 'Outfit', height: 1.5), textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _toggling ? null : _toggleMember,
          style: ElevatedButton.styleFrom(backgroundColor: _isMember ? AppColors.border : AppColors.primaryButton, minimumSize: const Size(200, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          child: _toggling ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isMember ? 'Leave Community' : 'Join Community', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ])),
    );
  }
}
