import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/verification_badge.dart';

// ─── Level ring gradient colors ──────────────────────────────────────────────
List<Color> _levelRingColors(int level) {
  if (level < 6)  return [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)];
  if (level < 16) return [const Color(0xFF43A047), const Color(0xFF66BB6A)];
  if (level < 26) return [const Color(0xFF1E88E5), const Color(0xFF42A5F5)];
  if (level < 41) return [const Color(0xFF8E24AA), const Color(0xFFAB47BC)];
  return             [const Color(0xFFF9A825), const Color(0xFFFFD54F)];
}

String _formatStatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _ownUidProvider = FutureProvider.autoDispose<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('uid');
});

final _profileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, uid) async {
  final res = await dioClient.get('/v1/user/$uid');
  final data = res.data;
  if (data['success'] == true && data['data'] != null) return Map<String, dynamic>.from(data['data']);
  if (data['id'] != null) return Map<String, dynamic>.from(data);
  throw Exception('Invalid profile data');
});

final _levelProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, uid) async {
  try {
    final res = await dioClient.get('/v1/levels/user/$uid');
    if (res.data['success'] == true && res.data['data'] != null) {
      return Map<String, dynamic>.from(res.data['data']);
    }
  } catch (_) {}
  return {'currentLevel': 1, 'levelTitle': 'Newcomer', 'currentXP': 0, 'xpForNextLevel': 100};
});

final _streakProvider = FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  try {
    final res = await dioClient.get('/v1/streaks/$uid');
    if (res.data['success'] == true && res.data['data'] != null) {
      return (res.data['data']['currentStreak'] as num?)?.toInt() ?? 0;
    }
  } catch (_) {}
  return 0;
});

final _postsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _PostsKey>((ref, key) async {
  try {
    final res = await dioClient.get('/v1/posts/${key.profileId}/${key.viewerId}?page=${key.page}&limit=12');
    final data = res.data;
    if (data != null && data['posts'] != null) {
      return List<Map<String, dynamic>>.from((data['posts'] as List).map((e) => Map<String, dynamic>.from(e)));
    }
  } catch (_) {}
  return [];
});

final _followStatusProvider = FutureProvider.autoDispose.family<bool, _FollowKey>((ref, key) async {
  try {
    final res = await dioClient.get('/v1/followers/${key.myId}/status/${key.targetId}');
    return res.data['data']?['isFollowing'] == true;
  } catch (_) {}
  return false;
});

final _groupsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, uid) async {
  try {
    final res = await dioClient.get('/v1/groups/user/$uid');
    final raw = res.data;
    List list = raw is List ? raw : (raw['data'] ?? []);
    return list
        .map((e) => Map<String, dynamic>.from(e))
        .where((g) => g['group_type'] == 'public' && g['hide_from_explore'] != true)
        .toList();
  } catch (_) {}
  return [];
});

class _PostsKey {
  final String profileId;
  final String viewerId;
  final int page;
  const _PostsKey(this.profileId, this.viewerId, this.page);
  @override bool operator ==(Object o) => o is _PostsKey && o.profileId == profileId && o.viewerId == viewerId && o.page == page;
  @override int get hashCode => Object.hash(profileId, viewerId, page);
}

class _FollowKey {
  final String myId;
  final String targetId;
  const _FollowKey(this.myId, this.targetId);
  @override bool operator ==(Object o) => o is _FollowKey && o.myId == myId && o.targetId == targetId;
  @override int get hashCode => Object.hash(myId, targetId);
}

// ─── ProfileScreen (own profile tab) ─────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(_ownUidProvider);
    return uidAsync.when(
      loading: () => Scaffold(backgroundColor: context.colors.background, body: const _ProfileSkeleton()),
      error: (e, _) => Scaffold(backgroundColor: context.colors.background, body: Center(child: Text('$e', style: TextStyle(color: context.colors.text)))),
      data: (uid) {
        if (uid == null) return Scaffold(backgroundColor: context.colors.background, body: const _ProfileSkeleton());
        return _ProfileShell(profileUid: uid, viewerUid: uid, isOwnProfile: true);
      },
    );
  }
}

// ─── UserProfileScreen (other user's profile) ────────────────────────────────

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(_ownUidProvider);
    return uidAsync.when(
      loading: () => Scaffold(backgroundColor: context.colors.background, body: const _ProfileSkeleton()),
      error: (e, _) => Scaffold(backgroundColor: context.colors.background, body: Center(child: Text('$e', style: TextStyle(color: context.colors.text)))),
      data: (myUid) => _ProfileShell(
        profileUid: userId,
        viewerUid: myUid ?? '',
        isOwnProfile: myUid == userId,
      ),
    );
  }
}

// ─── Shared Profile Shell ─────────────────────────────────────────────────────

class _ProfileShell extends ConsumerStatefulWidget {
  final String profileUid;
  final String viewerUid;
  final bool isOwnProfile;
  const _ProfileShell({required this.profileUid, required this.viewerUid, required this.isOwnProfile});

  @override
  ConsumerState<_ProfileShell> createState() => _ProfileShellState();
}

class _ProfileShellState extends ConsumerState<_ProfileShell> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isFollowing = false;
  bool _followLoading = false;
  bool _isBlocked = false;
  int _followerCount = 0;
  bool _showImageViewer = false;
  String? _imageViewerUrl;
  bool _showQrModal = false;
  int _postsPage = 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    if (widget.isOwnProfile || widget.viewerUid.isEmpty) return;
    try {
      final res = await dioClient.get('/v1/block/check', queryParameters: {
        'blocker_id': widget.viewerUid,
        'blocked_id': widget.profileUid,
      });
      if (mounted) {
        setState(() {
          _isBlocked = res.data['data']?['i_blocked_them'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (widget.viewerUid.isEmpty) return;
    setState(() => _followLoading = true);
    try {
      final res = await dioClient.post('/v1/followers/toggle', data: {
        'followingId': widget.profileUid,
        'followerId': widget.viewerUid,
      });
      final newState = res.data['data']?['isFollowing'] as bool? ?? !_isFollowing;
      setState(() {
        _isFollowing = newState;
        _followerCount += newState ? 1 : -1;
      });
    } catch (e) {
      if (mounted) _showSnack('Failed to update follow status');
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _blockUser() async {
    try {
      final res = await dioClient.post('/v1/block/block', data: {
        'blocker_id': widget.viewerUid,
        'blocked_id': widget.profileUid,
      });
      if (res.data['success'] == true) {
        setState(() => _isBlocked = true);
        _showSnack('User blocked');
      }
    } catch (_) {
      _showSnack('Failed to block user');
    }
  }

  Future<void> _unblockUser() async {
    try {
      final res = await dioClient.post('/v1/block/unblock', data: {
        'blocker_id': widget.viewerUid,
        'blocked_id': widget.profileUid,
      });
      if (res.data['success'] == true) {
        setState(() => _isBlocked = false);
        _showSnack('User unblocked');
      }
    } catch (_) {
      _showSnack('Failed to unblock user');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _shareProfile(String username) async {
    final url = 'https://witalk.in/$username';
    await SharePlus.instance.share(ShareParams(text: "Check out $username's profile on WiTalk: $url", subject: 'WiTalk Profile'));
  }

  void _showMenuSheet(Map<String, dynamic> profile) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
          _SheetOption(icon: Icons.flag_outlined, label: 'Report', color: colors.text, onTap: () {
            Navigator.pop(context);
            context.push('/report/user/${profile['id']}');
          }),
          _SheetOption(icon: Icons.link, label: 'Copy Profile URL', color: colors.text, onTap: () {
            Navigator.pop(context);
            Clipboard.setData(ClipboardData(text: 'https://witalk.in/${profile['username']}'));
            _showSnack('Profile URL copied');
          }),
          _SheetOption(
            icon: _isBlocked ? Icons.check_circle_outline : Icons.block,
            label: _isBlocked ? 'Unblock User' : 'Block User',
            color: _isBlocked ? colors.primary : const Color(0xFFFF3040),
            onTap: () {
              Navigator.pop(context);
              if (_isBlocked) {
                _unblockUser();
              } else {
                showDialog(context: context, builder: (_) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text('Block User', style: TextStyle(color: colors.text)),
                  content: Text('Block ${profile['name'] ?? profile['username']}?', style: TextStyle(color: colors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: colors.textSecondary))),
                    TextButton(onPressed: () { Navigator.pop(context); _blockUser(); }, child: const Text('Block', style: TextStyle(color: Color(0xFFFF3040)))),
                  ],
                ));
              }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profileAsync = ref.watch(_profileProvider(widget.profileUid));
    final levelAsync = ref.watch(_levelProvider(widget.profileUid));
    final streakAsync = ref.watch(_streakProvider(widget.profileUid));
    final followAsync = !widget.isOwnProfile && widget.viewerUid.isNotEmpty
        ? ref.watch(_followStatusProvider(_FollowKey(widget.viewerUid, widget.profileUid)))
        : null;
    final postsAsync = ref.watch(_postsProvider(_PostsKey(
      widget.profileUid,
      widget.viewerUid.isNotEmpty ? widget.viewerUid : widget.profileUid,
      _postsPage,
    )));
    final groupsAsync = ref.watch(_groupsProvider(widget.profileUid));

    if (profileAsync.isLoading) {
      return Scaffold(backgroundColor: colors.background, body: const _ProfileSkeleton());
    }

    if (profileAsync.hasError) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: colors.error),
          const SizedBox(height: 16),
          Text('Unable to Load Profile', style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${profileAsync.error}', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () => ref.invalidate(_profileProvider(widget.profileUid)),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ])),
      );
    }

    final profile = profileAsync.value!;

    // Sync follow state from server on first load
    if (followAsync != null && followAsync.hasValue && !_followLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_followLoading) {
          final serverFollow = followAsync.value!;
          if (_isFollowing != serverFollow) {
            setState(() => _isFollowing = serverFollow);
          }
        }
      });
    }

    // Sync follower count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final count = (profile['followers_count'] as num?)?.toInt() ?? 0;
        if (_followerCount == 0 && count != 0) {
          setState(() => _followerCount = count);
        }
      }
    });

    final levelData = levelAsync.value ?? {'currentLevel': 1, 'levelTitle': 'Newcomer'};
    final streak = streakAsync.value ?? 0;
    final posts = postsAsync.value ?? [];
    final groups = groupsAsync.value ?? [];

    final level = (levelData['currentLevel'] as num?)?.toInt() ?? 1;
    final levelTitle = levelData['levelTitle'] as String? ?? 'Newcomer';
    final ringColors = _levelRingColors(level);
    final avatarFrameUrl = profile['avatar_frame']?['image_url'] as String?;
    final name = profile['name'] as String? ?? '';
    final username = profile['username'] as String? ?? '';
    final bio = profile['bio'] as String?;
    final profilePic = profile['profile_pic'] as String?;
    final isVerified = profile['is_verified'] == true;
    final verificationBadge = profile['verification_badge'];
    final followerCount = _followerCount > 0 ? _followerCount : (profile['followers_count'] as num?)?.toInt() ?? 0;
    final friendsCount = (profile['friends_count'] as num?)?.toInt() ?? 0;
    final totalPosts = posts.length;
    final privacyRaw = profile['privacy_settings'];
    Map<String, dynamic> privacy = {'gender': true, 'country': true, 'city': true, 'interests': true};
    if (privacyRaw != null) {
      try {
        final parsed = privacyRaw is String ? {} : Map<String, dynamic>.from(privacyRaw as Map);
        privacy = {...privacy, ...parsed};
      } catch (_) {}
    }

    bool privacyOn(String key) {
      final v = privacy[key];
      if (v == null) return true;
      if (v is bool) return v;
      if (v is String) return v != 'false' && v != '0' && v.isNotEmpty;
      if (v is num) return v != 0;
      return true;
    }

    // ── Image viewer overlay ────────────────────────────────────────────
    if (_showImageViewer && _imageViewerUrl != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() { _showImageViewer = false; _imageViewerUrl = null; }),
          child: PhotoView(imageProvider: CachedNetworkImageProvider(_imageViewerUrl!)),
        ),
      );
    }

    // ── QR Modal overlay ───────────────────────────────────────────────
    if (_showQrModal) {
      return _QrModal(
        username: username,
        colors: colors,
        isOwnProfile: widget.isOwnProfile,
        onClose: () => setState(() => _showQrModal = false),
        onShare: () => _shareProfile(username),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.text),
              onPressed: () => context.pop(),
            ),
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(username, style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
              if (isVerified) ...[
                const SizedBox(width: 4),
                VerificationBadge(size: 18),
              ],
            ]),
            centerTitle: true,
            actions: [
              if (widget.isOwnProfile)
                const SizedBox(width: 48)
              else
                IconButton(
                  icon: Icon(Icons.more_vert, color: colors.text),
                  onPressed: () => _showMenuSheet(profile),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Divider(height: 1, thickness: 0.5, color: colors.border),
            ),
          ),

          // ── Hero card ──────────────────────────────────────────────────
          SliverToBoxAdapter(child: _HeroCard(
            name: name,
            username: username,
            bio: bio,
            profilePic: profilePic,
            isVerified: isVerified,
            verificationBadge: verificationBadge,
            level: level,
            levelTitle: levelTitle,
            ringColors: ringColors,
            avatarFrameUrl: avatarFrameUrl,
            streak: streak,
            totalPosts: totalPosts,
            followerCount: followerCount,
            friendsCount: friendsCount,
            colors: colors,
            onAvatarTap: profilePic != null ? () => setState(() { _showImageViewer = true; _imageViewerUrl = profilePic; }) : null,
            onFollowersPress: () => context.push('/followers/${profile['id']}?tab=followers'),
            onFriendsPress: () => context.push('/followers/${profile['id']}?tab=friends'),
          )),

          // ── Action buttons ─────────────────────────────────────────────
          SliverToBoxAdapter(child: _ActionButtons(
            isOwnProfile: widget.isOwnProfile,
            isFollowing: _isFollowing,
            followLoading: _followLoading,
            colors: colors,
            onEditProfile: () => context.push('/edit-profile'),
            onShare: () => setState(() => _showQrModal = true),
            onFollow: _toggleFollow,
            onMessage: () {
              context.push('/chat/new', extra: {
                'userId': profile['id'],
                'name': name,
                'username': username,
                'profilePic': profilePic,
              });
            },
          )),

          // ── Tab bar (pinned) ───────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(tabController: _tabCtrl, colors: colors),
          ),
        ],

        // ── TabBarView is the direct body of NestedScrollView ──────────
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // Posts tab
            postsAsync.isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : posts.isEmpty
                    ? _EmptyPosts(isOwnProfile: widget.isOwnProfile, isBlocked: _isBlocked, colors: colors)
                    : _PostsGrid(posts: posts, colors: colors, onPostTap: (post) {
                        if (post['suffix'] != null) {
                          context.push('/post-view/${post['suffix']}');
                        } else {
                          context.push('/post/${post['id']}');
                        }
                      }),
            // About tab
            _AboutSection(
              profile: profile,
              groups: groups,
              privacy: privacy,
              privacyOn: privacyOn,
              colors: colors,
              onCommunityTap: (g) => context.push('/community-info/${g['id']}'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String name, username;
  final String? bio, profilePic, avatarFrameUrl;
  final dynamic verificationBadge;
  final bool isVerified;
  final int level, streak, totalPosts, followerCount, friendsCount;
  final String levelTitle;
  final List<Color> ringColors;
  final ThemeColors colors;
  final VoidCallback? onAvatarTap, onFollowersPress, onFriendsPress;

  const _HeroCard({
    required this.name, required this.username, required this.bio, required this.profilePic,
    required this.isVerified, required this.verificationBadge, required this.level,
    required this.levelTitle, required this.ringColors, required this.avatarFrameUrl,
    required this.streak, required this.totalPosts, required this.followerCount,
    required this.friendsCount, required this.colors,
    this.onAvatarTap, this.onFollowersPress, this.onFriendsPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: SizedBox(
              width: 92, height: 92,
              child: Stack(children: [
                // Ring gradient
                Container(
                  width: 92, height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarFrameUrl != null ? null : LinearGradient(colors: ringColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    color: avatarFrameUrl != null ? Colors.transparent : null,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.surface, width: 2)),
                    clipBehavior: Clip.hardEdge,
                    child: profilePic != null
                        ? CachedNetworkImage(imageUrl: profilePic!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _AvatarFallback(name: name, colors: colors))
                        : _AvatarFallback(name: name, colors: colors),
                  ),
                ),
                // Avatar frame overlay
                if (avatarFrameUrl != null)
                  Positioned(top: -16, left: -16, child: SizedBox(
                    width: 124, height: 124,
                    child: CachedNetworkImage(imageUrl: avatarFrameUrl!, fit: BoxFit.contain),
                  )),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name
            Text(name, style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Level + streak chips
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: ringColors),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.military_tech, size: 11, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('Lv.$level', style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFFFF3E0),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text('$streak', style: const TextStyle(color: Color(0xFFE65100), fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text(levelTitle, style: TextStyle(color: colors.textTertiary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11), maxLines: 1),
          ])),
        ]),

        // Bio
        if (bio != null && bio!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(bio!, style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.4)),
        ],

        // Stats row
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(children: [
            Divider(height: 0, thickness: 0.5, color: colors.border.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(children: [
                Text('$totalPosts', style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 2),
                Text('Posts', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 11)),
              ])),
              VerticalDivider(width: 1, thickness: 0.5, color: colors.border),
              Expanded(child: GestureDetector(
                onTap: onFollowersPress,
                child: Column(children: [
                  Text(_formatStatCount(followerCount), style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text('Followers', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 11)),
                ]),
              )),
              VerticalDivider(width: 1, thickness: 0.5, color: colors.border),
              Expanded(child: GestureDetector(
                onTap: onFriendsPress,
                child: Column(children: [
                  Text(_formatStatCount(friendsCount), style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text('Friends', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 11)),
                ]),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  final ThemeColors colors;
  const _AvatarFallback({required this.name, required this.colors});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: colors.border,
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: colors.text, fontSize: 28, fontFamily: 'Outfit', fontWeight: FontWeight.w700),
    )),
  );
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final bool isOwnProfile, isFollowing, followLoading;
  final ThemeColors colors;
  final VoidCallback onEditProfile, onShare, onFollow, onMessage;

  const _ActionButtons({
    required this.isOwnProfile, required this.isFollowing, required this.followLoading,
    required this.colors, required this.onEditProfile, required this.onShare,
    required this.onFollow, required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(children: [
        if (isOwnProfile) ...[
          _ActionBtn(label: 'Edit Profile', icon: Icons.edit_outlined, colors: colors, outline: true, onTap: onEditProfile),
          const SizedBox(width: 8),
          _ActionBtn(label: 'Share', icon: Icons.share_outlined, colors: colors, outline: true, onTap: onShare),
        ] else ...[
          Expanded(child: isFollowing
              ? _ActionBtn(label: 'Following', icon: null, colors: colors, outline: true, expanded: true,
                  trailing: const Icon(Icons.keyboard_arrow_down, size: 16),
                  onTap: onFollow, loading: followLoading)
              : _ActionBtn(label: 'Follow', icon: null, colors: colors, outline: false, expanded: true, primary: true,
                  onTap: onFollow, loading: followLoading)),
          const SizedBox(width: 8),
          Expanded(child: _ActionBtn(label: 'Message', icon: Icons.chat_bubble_outline, colors: colors, outline: true, expanded: true, onTap: onMessage)),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ThemeColors colors;
  final bool outline, primary, expanded;
  final bool loading;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label, required this.icon, required this.colors, required this.onTap,
    this.outline = false, this.primary = false, this.expanded = false, this.loading = false, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: outline ? colors.text : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: outline ? colors.text : Colors.white), const SizedBox(width: 5)],
            Text(label, style: TextStyle(color: outline ? colors.text : Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
            if (trailing != null) ...[const SizedBox(width: 3), trailing!],
          ]);

    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : (primary ? colors.primary : colors.primary),
          borderRadius: BorderRadius.circular(22),
          border: outline ? Border.all(color: colors.border) : null,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    return expanded ? btn : Expanded(child: btn);
  }
}

// ─── Tab bar persistent header ────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ThemeColors colors;
  const _TabBarDelegate({required this.tabController, required this.colors});

  // Flutter's kTabHeight = 46; border is a decoration so it doesn't add to layout height
  static const double _kHeight = 46;
  @override double get minExtent => _kHeight;
  @override double get maxExtent => _kHeight;
  @override bool shouldRebuild(covariant _TabBarDelegate old) => old.colors != colors;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textTertiary,
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorWeight: 2,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        tabs: const [
          _TabItem(icon: Icons.grid_on, label: 'Posts'),
          _TabItem(icon: Icons.info_outline, label: 'About'),
        ],
      ),
    );
  }
}

// ─── Posts Grid ───────────────────────────────────────────────────────────────

// TabBar propagates labelColor/unselectedLabelColor via IconTheme + DefaultTextStyle
class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
      ]),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final ThemeColors colors;
  final void Function(Map<String, dynamic>) onPostTap;

  const _PostsGrid({required this.posts, required this.colors, required this.onPostTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1, childAspectRatio: 2 / 3,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) => _PostTile(post: posts[i], colors: colors, onTap: () => onPostTap(posts[i])),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _PostTile({required this.post, required this.colors, required this.onTap});

  String? _firstImageUrl() {
    try {
      final raw = post['media_data'];
      if (raw == null) return null;
      List media = raw is List ? raw : [];
      if (media.isEmpty) return null;
      final first = Map<String, dynamic>.from(media[0] as Map);
      if (first['type'] == 'image') return first['url'] as String?;
      if (first['type'] == 'video') return first['thumbnail'] as String?;
    } catch (_) {}
    final imgs = post['images'];
    if (imgs is List && imgs.isNotEmpty) return imgs[0] as String?;
    return null;
  }

  bool _isVideo() {
    if (post['media_type'] == 'video') return true;
    try {
      final raw = post['media_data'];
      if (raw == null) return false;
      List media = raw is List ? raw : [];
      if (media.isEmpty) return false;
      return (media[0] as Map)['type'] == 'video';
    } catch (_) {}
    return false;
  }

  bool _hasMultiple() {
    try {
      final raw = post['media_data'];
      if (raw == null) return false;
      List media = raw is List ? raw : [];
      return media.length > 1;
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _firstImageUrl();
    final isVideo = _isVideo();
    final hasMultiple = _hasMultiple();
    final views = post['views'];

    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        imgUrl != null
            ? CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => ColoredBox(color: colors.surface))
            : Container(
                color: colors.surface,
                padding: const EdgeInsets.all(8),
                child: Text(post['content'] as String? ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'Outfit'), maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
        if (isVideo)
          const Positioned(top: 4, left: 4, child: Icon(Icons.play_circle_outline, size: 20, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
        if (hasMultiple)
          Positioned(top: 4, right: 4, child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.collections, size: 14, color: Colors.white),
          )),
        if (views != null)
          Positioned(bottom: 4, right: 4, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility, size: 12, color: Colors.white),
              const SizedBox(width: 2),
              Text(
                (views as num) >= 1000 ? '${((views) / 1000).toStringAsFixed(1)}K' : '$views',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
              ),
            ]),
          )),
      ]),
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  final bool isOwnProfile, isBlocked;
  final ThemeColors colors;
  const _EmptyPosts({required this.isOwnProfile, required this.isBlocked, required this.colors});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(isBlocked ? Icons.block : Icons.photo_camera_outlined, size: 64, color: colors.textTertiary),
      const SizedBox(height: 14),
      Text(isBlocked ? 'No posts available' : (isOwnProfile ? 'No posts yet' : 'No posts to show'),
          style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      if (!isBlocked)
        Text(isOwnProfile ? 'Start sharing your moments!' : "When they share posts, you'll see them here.",
            style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.5), textAlign: TextAlign.center),
    ]),
  ));
}

// ─── About Section ────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> groups;
  final Map<String, dynamic> privacy;
  final bool Function(String) privacyOn;
  final ThemeColors colors;
  final void Function(Map<String, dynamic>) onCommunityTap;

  const _AboutSection({
    required this.profile, required this.groups, required this.privacy,
    required this.privacyOn, required this.colors, required this.onCommunityTap,
  });

  int? _calculateAge(String? birthday) {
    if (birthday == null) return null;
    try {
      final parts = birthday.split(RegExp(r'[-T]'));
      final birth = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      return age;
    } catch (_) {}
    return null;
  }

  String _formatJoinedDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final gender = profile['gender'] as String?;
    final country = profile['country'] as String?;
    final city = profile['city'] as String?;
    final school = profile['school'] as String?;
    final occupation = profile['occupation'] as String?;
    final createdAt = profile['created_at'] as String?;
    final birthday = profile['birthday'] as String?;
    final age = _calculateAge(birthday);
    final interests = profile['interests'];
    final List<String> interestList = interests is List ? List<String>.from(interests.map((e) => '$e')) : [];

    final showGender = privacyOn('gender') && gender != null && (gender.toLowerCase() == 'male' || gender.toLowerCase() == 'female');
    final showCountry = privacyOn('country') && country != null && country.isNotEmpty;
    final showCity = privacyOn('city') && city != null && city.isNotEmpty;
    final showInterests = privacyOn('interests') && interestList.isNotEmpty;
    final hasAnyAbout = showGender || showCountry || showCity || createdAt != null || age != null || (school != null && school.isNotEmpty) || (occupation != null && occupation.isNotEmpty);

    return ListView(padding: EdgeInsets.zero, children: [
      _AboutCard(colors: colors, children: [
        if (!hasAnyAbout)
          Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Column(children: [
            Icon(Icons.info_outline, size: 36, color: colors.textTertiary),
            const SizedBox(height: 8),
            Text('No information shared', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
          ]))),
        if (showGender)
          _InfoRow(icon: gender.toLowerCase() == 'male' ? Icons.male : Icons.female, label: 'Gender', value: '${gender[0].toUpperCase()}${gender.substring(1)}', colors: colors),
        if (age != null)
          _InfoRow(icon: Icons.cake_outlined, label: 'Age', value: '$age years old', colors: colors),
        if (showCountry)
          _InfoRow(icon: Icons.public, label: 'Country', value: country, colors: colors),
        if (showCity)
          _InfoRow(icon: Icons.location_on_outlined, label: 'City', value: city, colors: colors),
        if (school != null && school.isNotEmpty)
          _InfoRow(icon: Icons.school_outlined, label: 'School', value: school, colors: colors),
        if (occupation != null && occupation.isNotEmpty)
          _InfoRow(icon: Icons.work_outline, label: 'Occupation', value: occupation, colors: colors),
        if (createdAt != null)
          _InfoRow(icon: Icons.event_outlined, label: 'Joined', value: _formatJoinedDate(createdAt), colors: colors, isLast: true),
      ]),
      if (showInterests)
        _AboutCard(colors: colors, margin: const EdgeInsets.fromLTRB(12, 10, 12, 0), children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.interests, size: 18, color: colors.primary)),
            const SizedBox(width: 10),
            Text('Interests', style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Wrap(spacing: 7, runSpacing: 7, children: interestList.map((i) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.primary.withValues(alpha: 0.3))),
            child: Text(i, style: TextStyle(color: colors.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 12)),
          )).toList())),
        ]),
      if (groups.isNotEmpty)
        _AboutCard(colors: colors, margin: const EdgeInsets.fromLTRB(12, 10, 12, 0), children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.groups, size: 18, color: colors.primary)),
            const SizedBox(width: 10),
            Text('Part of these Communities', style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
          ])),
          SizedBox(height: 90, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final g = groups[i];
              final pic = g['picture'] as String?;
              final gName = g['name'] as String? ?? 'C';
              return GestureDetector(
                onTap: () => onCommunityTap(g),
                child: SizedBox(width: 68, child: Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 52, height: 52,
                    child: pic != null
                        ? CachedNetworkImage(imageUrl: pic, fit: BoxFit.cover)
                        : Container(color: colors.primary.withValues(alpha: 0.3), child: Center(child: Text(gName[0].toUpperCase(), style: TextStyle(color: colors.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20)))),
                  )),
                  const SizedBox(height: 5),
                  Text(gName, style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ])),
              );
            },
          )),
        ]),
      const SizedBox(height: 40),
    ]);
  }
}

class _AboutCard extends StatelessWidget {
  final List<Widget> children;
  final ThemeColors colors;
  final EdgeInsets margin;
  const _AboutCard({required this.children, required this.colors, this.margin = const EdgeInsets.fromLTRB(12, 12, 12, 0)});
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border, width: 0.5)),
    clipBehavior: Clip.hardEdge,
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final ThemeColors colors;
  final bool isLast;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.colors, this.isLast = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5), width: 0.5))),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: colors.primary)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: colors.textTertiary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11)),
        Text(value, style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    ]),
  );
}

// ─── QR Modal ─────────────────────────────────────────────────────────────────

class _QrModal extends StatelessWidget {
  final String username;
  final ThemeColors colors;
  final bool isOwnProfile;
  final VoidCallback onClose, onShare;

  const _QrModal({required this.username, required this.colors, required this.isOwnProfile, required this.onClose, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.overlay,
      body: GestureDetector(
        onTap: onClose,
        child: Center(child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Share Profile', style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18)),
                GestureDetector(onTap: onClose, child: Icon(Icons.close, color: colors.text)),
              ]),
              const SizedBox(height: 8),
              Text('Scan this QR code to view profile', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('witalk.in/$username', style: TextStyle(color: colors.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8)),
                child: Text('https://witalk.in/$username', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: onShare,
                style: ElevatedButton.styleFrom(backgroundColor: colors.primary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                label: const Text('Share Profile', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        )),
      ),
    );
  }
}

// ─── Skeleton Loader ──────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1a1f2e) : const Color(0xFFE1E9EE);
    final highlightColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(children: [
        // Header
        Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ])),
        // Hero card
        Container(
          margin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 92, height: 92, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 20, width: 140, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 14, width: 100, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 8, width: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: List.generate(3, (_) => Expanded(child: Container(height: 32, color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 4))))),
          ]),
        ),
        // Action buttons
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Row(children: [
          Expanded(child: Container(height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)))),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)))),
        ])),
        // Tab bar
        Container(height: 48, color: Colors.white),
        const SizedBox(height: 1),
        // Posts grid
        Expanded(child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1, childAspectRatio: 2 / 3),
          itemCount: 9,
          itemBuilder: (_, __) => Container(color: Colors.white),
        )),
      ]),
    );
  }
}

// ─── Bottom sheet option row ──────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
        ]),
      ),
    );
  }
}
