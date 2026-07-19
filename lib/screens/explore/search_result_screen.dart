import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/post_card.dart';

// ---------------------------------------------------------------------------
// SearchResultScreen — simple combined-list variant (users + channels + posts)
// Used when navigating with a pre-provided query (e.g. from hashtag taps).
// ---------------------------------------------------------------------------
class SearchResultScreen extends ConsumerStatefulWidget {
  final String query;
  const SearchResultScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _channels = [];

  bool _loading = false;
  bool _loadingMore = false;

  int _userOffset = 0, _postOffset = 0, _channelOffset = 0;
  bool _hasMoreUsers = true, _hasMorePosts = true, _hasMoreChannels = true;

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) _performSearch(initial: true);
  }

  Future<void> _performSearch({required bool initial}) async {
    if (initial) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    const limit = 10;
    try {
      final uid = ref.read(authProvider).uid ?? '';
      final res = await dioClient.get(
        '/v1/search',
        queryParameters: {
          'q': widget.query,
          'userLimit': limit,
          'postLimit': limit,
          'channelLimit': limit,
          'userOffset': initial ? 0 : _userOffset,
          'postOffset': initial ? 0 : _postOffset,
          'channelOffset': initial ? 0 : _channelOffset,
        },
      );

      if (res.data['success'] == true) {
        final d = res.data['data'] as Map<String, dynamic>;
        final newUsers = ((d['users'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .where((u) => u['id']?.toString() != uid && u['role'] == 'user')
            .toList();
        final newPosts = ((d['posts'] as List?) ?? []).cast<Map<String, dynamic>>();
        final newChans = ((d['channels'] as List?) ?? []).cast<Map<String, dynamic>>();

        setState(() {
          if (initial) {
            _users = newUsers;
            _posts = newPosts;
            _channels = newChans;
          } else {
            _users = [..._users, ...newUsers];
            _posts = [..._posts, ...newPosts];
            _channels = [..._channels, ...newChans];
          }
          _userOffset = (initial ? 0 : _userOffset) + newUsers.length;
          _postOffset = (initial ? 0 : _postOffset) + newPosts.length;
          _channelOffset = (initial ? 0 : _channelOffset) + newChans.length;
          _hasMoreUsers = newUsers.length >= limit;
          _hasMorePosts = newPosts.length >= limit;
          _hasMoreChannels = newChans.length >= limit;
        });
      }
    } catch (_) {}

    if (mounted) setState(() { _loading = false; _loadingMore = false; });
  }

  void _handleLoadMore() {
    if (_loadingMore || _loading) return;
    if (_hasMoreUsers || _hasMorePosts || _hasMoreChannels) {
      _performSearch(initial: false);
    }
  }

  Future<void> _handleChannelSubscribe(Map<String, dynamic> channel) async {
    final id = channel['id'].toString();
    final wasSub = channel['is_subscribed'] == true;
    try {
      if (wasSub) {
        await dioClient.delete('/v1/channels/$id/subscribe');
      } else {
        await dioClient.post('/v1/channels/$id/subscribe');
      }
      setState(() {
        _channels = _channels.map((c) {
          if (c['id'].toString() == id) {
            return {
              ...c,
              'is_subscribed': !wasSub,
              'subscriber_count': (c['subscriber_count'] as int? ?? 0) + (wasSub ? -1 : 1),
            };
          }
          return c;
        }).toList();
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _displayData => [
    ..._users.map((u) => {...u, '_type': 'user'}),
    ..._channels.map((c) => {...c, '_type': 'channel'}),
    ..._posts.map((p) => {...p, '_type': 'post'}),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currentUserId = ref.watch(authProvider).uid;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(c),
        if (_loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: c.primaryButton)))
        else
          Expanded(child: _buildList(c, currentUserId)),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.card, border: Border.all(color: c.border)),
            child: Icon(Icons.arrow_back, color: c.text, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Search Results', style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 18)),
          const SizedBox(height: 2),
          Text('"${widget.query}"', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14)),
        ])),
      ]),
    );
  }

  Widget _buildList(ThemeColors c, String? currentUserId) {
    final data = _displayData;
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 64, color: c.textTertiary),
            const SizedBox(height: 16),
            Text('No results found', style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 18)),
            const SizedBox(height: 8),
            Text('Try searching for something else', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14)),
          ]),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          _handleLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: data.length + (_loadingMore ? 1 : 0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (_, i) {
          if (i == data.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Loading more results...', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14)),
              ]),
            );
          }
          final item = data[i];
          final type = item['_type'] as String;
          if (type == 'user') return _buildUserItem(item, c);
          if (type == 'channel') return _buildChannelItem(item, c);
          return _buildPostItem(item, c, currentUserId);
        },
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> item, ThemeColors c) {
    final pic = item['profile_pic'] as String?;
    final name = item['name']?.toString() ?? '';
    final username = item['username']?.toString() ?? '';
    final bio = item['bio']?.toString();
    final city = item['city']?.toString();
    final followers = item['followers_count'] as int? ?? 0;
    final isOnline = item['is_online'] == 1;

    return GestureDetector(
      onTap: () => context.push('/user/${item['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: c.border,
            backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isOnline) ...[
                const SizedBox(width: 6),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle, border: Border.all(color: c.card, width: 1.5))),
              ],
            ]),
            const SizedBox(height: 2),
            Text('@$username', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14)),
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(bio, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (city != null && city.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on, size: 14, color: c.textTertiary),
                const SizedBox(width: 2),
                Text(city, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12)),
              ]),
            ],
          ])),
          Column(children: [
            Text('$followers', style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 16)),
            const SizedBox(height: 2),
            Text('Followers', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildChannelItem(Map<String, dynamic> item, ThemeColors c) {
    final icon = item['icon'] as String?;
    final name = item['name']?.toString() ?? 'C';
    final description = item['description']?.toString();
    final subs = item['subscriber_count'] as int? ?? 0;
    final isSubscribed = item['is_subscribed'] == true;
    final isVerified = item['is_verified'] == true || item['is_verified'] == 1;

    return GestureDetector(
      onTap: () => context.push('/channel/${item['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          icon != null
              ? CircleAvatar(radius: 26, backgroundImage: CachedNetworkImageProvider(icon), backgroundColor: c.border)
              : CircleAvatar(radius: 26, backgroundColor: c.primary,
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Outfit-Bold', fontSize: 22))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 14, color: c.primary),
              ],
            ]),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(description, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Text('${subs.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} subscribers',
                style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12)),
          ])),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleChannelSubscribe(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSubscribed ? c.card : c.primary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSubscribed ? c.border : c.primary),
              ),
              child: Text(
                isSubscribed ? 'Joined' : 'View',
                style: TextStyle(color: isSubscribed ? c.text : Colors.white, fontFamily: 'Outfit-SemiBold', fontSize: 13),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> item, ThemeColors c, String? currentUserId) {
    final post = {
      'id': item['id'],
      'user_id': item['user_id'],
      'content': item['content'],
      'likes': item['likes'] ?? 0,
      'comments': item['comments'] ?? 0,
      'shares': item['shares'] ?? 0,
      'views': item['views'] ?? 0,
      'created_on': item['created_on'],
      'updated_on': item['updated_on'],
      'media': item['media_data'] ?? [],
      'isLiked': item['is_liked'] ?? false,
      'user': {
        'id': item['user_id'],
        'name': item['user_name'],
        'username': item['username'],
        'profile_pic': item['profile_pic'],
        'is_verified': item['is_verified'],
        'verification_badge': item['verification_badge'],
      },
      'isFollowing': item['is_following'] ?? false,
      'suffix': item['suffix'],
    };
    return PostCard(
      post: post,
      currentUserId: currentUserId,
      onLikeUpdate: (postId, isLiked, count) {
        setState(() {
          _posts = _posts.map((p) => p['id'].toString() == postId
              ? {...p, 'is_liked': isLiked, 'likes': count}
              : p).toList();
        });
      },
      onCommentUpdate: (postId, count) {
        setState(() {
          _posts = _posts.map((p) => p['id'].toString() == postId
              ? {...p, 'comments': count}
              : p).toList();
        });
      },
      onShowMoreMenu: (postId, userId, extra) {
        _showPostMenu(postId, userId, c);
      },
    );
  }

  void _showPostMenu(String postId, String userId, ThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.bookmark_border, color: c.text),
          title: Text('Save post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: Icon(Icons.flag_outlined, color: c.text),
          title: Text('Report', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); context.push('/report/post/$postId'); },
        ),
        ListTile(
          leading: Icon(Icons.block, color: c.text),
          title: Text('Block user', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
