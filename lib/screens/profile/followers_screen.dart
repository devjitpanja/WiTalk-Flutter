import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class FollowersScreen extends ConsumerStatefulWidget {
  final String userId;
  const FollowersScreen({super.key, required this.userId});
  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _followers = [], _following = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final f1 = await dioClient.get('/v1/followers/${widget.userId}/followers');
      final f2 = await dioClient.get('/v1/followers/${widget.userId}/following');
      final followers = f1.data['data'];
      final following = f2.data['data'];
      if (mounted) setState(() {
        _followers = followers is List ? followers : (followers is Map ? (followers['followers'] as List? ?? []) : []);
        _following = following is List ? following : (following is Map ? (following['following'] as List? ?? []) : []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Connections', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primaryButton,
        tabs: [
          Tab(text: 'Followers (${_followers.length})'),
          Tab(text: 'Following (${_following.length})'),
        ],
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
        : TabBarView(controller: _tabCtrl, children: [_UserList(users: _followers), _UserList(users: _following)]),
  );
}

class _UserList extends StatelessWidget {
  final List<dynamic> users;
  const _UserList({required this.users});

  @override
  Widget build(BuildContext context) => users.isEmpty
      ? const Center(child: Text('No users', style: TextStyle(color: Colors.white70, fontFamily: 'Outfit')))
      : ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i] as Map<String, dynamic>;
            final name = u['name'] as String? ?? '';
            final pic = u['profile_pic'] as String?;
            final id = u['id'] as String? ?? '';
            final username = u['username'] as String?;
            return ListTile(
              leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border,
                backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null),
              title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              subtitle: username != null ? Text('@$username', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)) : null,
              onTap: () => context.push('/user/$id'),
            );
          },
        );
}
