import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';
import '../../widgets/common/verification_badge.dart';

final _myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('uid');
  final res = await dioClient.get('/v1/user/$uid');
  return res.data['data'] ?? {};
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_myProfileProvider).when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primaryButton))),
      error: (e, _) => Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('$e', style: const TextStyle(color: Colors.white70)))),
      data: (profile) => _ProfileView(profile: profile, isMe: true),
    );
  }
}

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(FutureProvider.autoDispose((ref) async {
      final res = await dioClient.get('/v1/user/$userId');
      return res.data['data'] ?? {};
    }));
    return profileAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primaryButton))),
      error: (e, _) => Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('$e', style: const TextStyle(color: Colors.white70)))),
      data: (profile) => _ProfileView(profile: profile, isMe: false),
    );
  }
}

class _ProfileView extends StatefulWidget {
  final Map<String, dynamic> profile;
  final bool isMe;
  const _ProfileView({required this.profile, required this.isMe});
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _isFollowing = widget.profile['is_following'] == true;
  }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final name = p['name'] ?? '';
    final username = p['username'];
    final bio = p['bio'];
    final pic = p['profile_pic'];
    final isVerified = p['is_verified'] == true;
    final followers = p['followers_count'] ?? 0;
    final following = p['following_count'] ?? 0;
    final posts = p['posts_count'] ?? 0;
    final id = p['id'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
            title: Text(username != null ? '@$username' : name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            actions: [
              if (widget.isMe)
                IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: () => context.push('/edit-profile'))
              else
                IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
            ],
          ),
          SliverToBoxAdapter(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
              CircleAvatar(radius: 44, backgroundColor: AppColors.border,
                backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 28)) : null),
              const SizedBox(width: 20),
              Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _stat('$posts', 'Posts'),
                GestureDetector(onTap: () => context.push('/followers/$id'), child: _stat('$followers', 'Followers')),
                GestureDetector(onTap: () => context.push('/followers/$id'), child: _stat('$following', 'Following')),
              ])),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, fontFamily: 'Outfit')),
                if (isVerified) ...[const SizedBox(width: 4), const VerificationBadge(size: 16)],
              ]),
              if (bio != null && (bio as String).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(bio, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Outfit'))),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: widget.isMe
                ? OutlinedButton(onPressed: () => context.push('/edit-profile'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppColors.border), minimumSize: const Size(double.infinity, 38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Edit Profile', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)))
                : Row(children: [
                    Expanded(child: ElevatedButton(onPressed: () => setState(() => _isFollowing = !_isFollowing),
                      style: ElevatedButton.styleFrom(backgroundColor: _isFollowing ? AppColors.border : AppColors.primaryButton, minimumSize: const Size(0, 38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => context.push('/chat/conversation/$id'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppColors.border), minimumSize: const Size(0, 38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Message', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)))),
                  ])),
            TabBar(controller: _tabCtrl, labelColor: Colors.white, unselectedLabelColor: AppColors.textTertiary, indicatorColor: AppColors.primaryButton,
              tabs: const [Tab(icon: Icon(Icons.grid_on, size: 22)), Tab(icon: Icon(Icons.video_library_outlined, size: 22)), Tab(icon: Icon(Icons.bookmark_outline, size: 22))]),
          ])),
        ],
        body: TabBarView(controller: _tabCtrl, children: [
          _PostsGrid(userId: id),
          const Center(child: Text('Videos', style: TextStyle(color: Colors.white70))),
          const Center(child: Text('Saved', style: TextStyle(color: Colors.white70))),
        ]),
      ),
    );
  }

  Widget _stat(String count, String label) => Column(children: [
    Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18, fontFamily: 'Outfit')),
    Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
  ]);
}

class _PostsGrid extends StatelessWidget {
  final String userId;
  const _PostsGrid({required this.userId});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Posts', style: TextStyle(color: Colors.white70)));
}
