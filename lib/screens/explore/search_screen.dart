import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/post_card.dart';

// ---------------------------------------------------------------------------
// Search history item model
// ---------------------------------------------------------------------------
class _HistoryItem {
  final int? dbId;
  final String type; // 'query' | 'user'
  final String? text;
  final String? id;
  final String? username;
  final String? name;
  final String? profilePic;
  final bool isVerified;

  const _HistoryItem({
    this.dbId,
    required this.type,
    this.text,
    this.id,
    this.username,
    this.name,
    this.profilePic,
    this.isVerified = false,
  });

  factory _HistoryItem.fromJson(Map<String, dynamic> j) => _HistoryItem(
        dbId: j['db_id'] as int?,
        type: (j['type'] as String?) ?? 'query',
        text: j['text'] as String?,
        id: j['id']?.toString(),
        username: j['username'] as String?,
        name: j['name'] as String?,
        profilePic: j['profile_pic'] as String?,
        isVerified: (j['is_verified'] == true || j['is_verified'] == 1),
      );

  Map<String, dynamic> toJson() {
    if (type == 'query') return {'type': 'query', 'text': text};
    return {
      'type': 'user',
      'id': id,
      'username': username,
      'name': name,
      'profile_pic': profilePic,
      'is_verified': isVerified,
    };
  }
}

// ---------------------------------------------------------------------------
// Pagination state
// ---------------------------------------------------------------------------
class _Pagination {
  final int userOffset, postOffset, communityOffset, channelOffset;
  final bool hasMoreUsers, hasMorePosts, hasMoreCommunities, hasMoreChannels;

  const _Pagination({
    this.userOffset = 0,
    this.postOffset = 0,
    this.communityOffset = 0,
    this.channelOffset = 0,
    this.hasMoreUsers = true,
    this.hasMorePosts = true,
    this.hasMoreCommunities = true,
    this.hasMoreChannels = true,
  });

  static const _Pagination zero = _Pagination();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabCtrl;

  // Results
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _channels = [];

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  String _searchedQuery = '';
  _Pagination _pagination = _Pagination.zero;

  // History
  List<_HistoryItem> _history = [];
  bool _showAllHistory = false;

  // Alert
  String? _alertTitle;
  String? _alertMessage;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadHistory();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── History ──────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final res = await dioClient.get('/v1/search/history');
      final data = res.data;
      if (data['success'] == true && data['data']?['history'] is List) {
        setState(() {
          _history = (data['data']['history'] as List)
              .map((j) => _HistoryItem.fromJson(j as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToHistory(_HistoryItem item) async {
    try {
      await dioClient.post('/v1/search/history', data: item.toJson());
      setState(() {
        List<_HistoryItem> filtered;
        if (item.type == 'query') {
          filtered = _history.where((h) => !(h.type == 'query' && h.text == item.text)).toList();
        } else {
          filtered = _history.where((h) => !(h.type == 'user' && h.id == item.id)).toList();
        }
        _history = [item, ...filtered].take(20).toList();
      });
    } catch (_) {}
  }

  Future<void> _removeFromHistory(int? dbId) async {
    if (dbId == null) return;
    try {
      await dioClient.delete('/v1/search/history/$dbId');
      setState(() => _history = _history.where((h) => h.dbId != dbId).toList());
    } catch (_) {}
  }

  Future<void> _clearAllHistory() async {
    try {
      await dioClient.delete('/v1/search/history');
      setState(() {
        _history = [];
        _showAllHistory = false;
      });
    } catch (_) {}
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _handleSearch() {
    final q = _queryCtrl.text.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    _saveToHistory(_HistoryItem(type: 'query', text: q));
    _pagination = _Pagination.zero;
    _searchedQuery = q;
    _performSearch(q, initial: true);
  }

  Future<void> _performSearch(String q, {required bool initial}) async {
    if (q.trim().length < 2) return;
    if (initial) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    const limit = 10;
    try {
      final uid = ref.read(authProvider).uid ?? '';
      final uOff = initial ? 0 : _pagination.userOffset;
      final pOff = initial ? 0 : _pagination.postOffset;
      final cOff = initial ? 0 : _pagination.communityOffset;
      final chOff = initial ? 0 : _pagination.channelOffset;

      final res = await dioClient.get(
        '/v1/search',
        queryParameters: {
          'q': q,
          'userLimit': limit,
          'postLimit': limit,
          'communityLimit': limit,
          'channelLimit': limit,
          'userOffset': uOff,
          'postOffset': pOff,
          'communityOffset': cOff,
          'channelOffset': chOff,
        },
      );

      if (res.data['success'] == true) {
        final d = res.data['data'] as Map<String, dynamic>;
        final newUsers = ((d['users'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .where((u) => u['id']?.toString() != uid && u['role'] == 'user')
            .toList();
        final newPosts = ((d['posts'] as List?) ?? []).cast<Map<String, dynamic>>();
        final newComms = ((d['communities'] as List?) ?? []).cast<Map<String, dynamic>>();
        final newChans = ((d['channels'] as List?) ?? []).cast<Map<String, dynamic>>();

        setState(() {
          if (initial) {
            _users = newUsers;
            _posts = newPosts;
            _communities = newComms;
            _channels = newChans;
          } else {
            _users = [..._users, ...newUsers];
            _posts = [..._posts, ...newPosts];
            _communities = [..._communities, ...newComms];
            _channels = [..._channels, ...newChans];
          }
          _pagination = _Pagination(
            userOffset: (initial ? 0 : _pagination.userOffset) + newUsers.length,
            postOffset: (initial ? 0 : _pagination.postOffset) + newPosts.length,
            communityOffset: (initial ? 0 : _pagination.communityOffset) + newComms.length,
            channelOffset: (initial ? 0 : _pagination.channelOffset) + newChans.length,
            hasMoreUsers: newUsers.length >= limit,
            hasMorePosts: newPosts.length >= limit,
            hasMoreCommunities: newComms.length >= limit,
            hasMoreChannels: newChans.length >= limit,
          );
          _hasSearched = true;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _handleClear() {
    _queryCtrl.clear();
    setState(() {
      _searchedQuery = '';
      _users = [];
      _posts = [];
      _communities = [];
      _channels = [];
      _hasSearched = false;
      _showAllHistory = false;
    });
    _focusNode.requestFocus();
  }

  void _handleHistoryItemPress(_HistoryItem item) {
    if (item.type == 'user') {
      _navigateToProfile(item.id!, item);
    } else {
      final q = item.text ?? '';
      _queryCtrl.text = q;
      _searchedQuery = q;
      _pagination = _Pagination.zero;
      FocusScope.of(context).unfocus();
      _saveToHistory(item);
      _performSearch(q, initial: true);
    }
  }

  void _navigateToProfile(String userId, [_HistoryItem? data]) {
    if (data != null) {
      _saveToHistory(_HistoryItem(
        type: 'user',
        id: data.id,
        username: data.username,
        name: data.name,
        profilePic: data.profilePic,
        isVerified: data.isVerified,
      ));
    }
    context.push('/user/$userId');
  }

  void _loadMoreForTab(String type) {
    if (_loadingMore || _loading) return;
    final hasMore = type == 'users'
        ? _pagination.hasMoreUsers
        : type == 'posts'
            ? _pagination.hasMorePosts
            : type == 'channels'
                ? _pagination.hasMoreChannels
                : _pagination.hasMoreCommunities;
    if (hasMore && _searchedQuery.isNotEmpty) {
      _performSearch(_searchedQuery, initial: false);
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
    } catch (e) {
      final status = (e as dynamic)?.response?.statusCode;
      if (status == 403) {
        setState(() {
          _alertTitle = 'Access Restricted';
          _alertMessage = 'You have been banned from this channel and cannot join it.';
        });
        _showAlert();
      }
    }
  }

  void _handleCommunityPress(Map<String, dynamic> community) {
    final id = community['id'].toString();
    if (community['is_member'] == true) {
      context.push('/chat/group/$id');
    } else {
      context.push('/community-info/$id');
    }
  }

  void _showAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(_alertTitle ?? '', style: TextStyle(color: context.colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text(_alertMessage ?? '', style: TextStyle(color: context.colors.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: context.colors.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(c),
          if (_loading)
            Expanded(child: Center(child: CircularProgressIndicator(color: c.primaryButton)))
          else if (_hasSearched)
            ..._buildResultsView(c)
          else if (_history.isNotEmpty)
            Expanded(child: _buildHistoryView(c))
          else
            Expanded(child: _buildEmptyState(c, searched: false)),
        ]),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
    return Container(
      color: c.surface,
      padding: const EdgeInsets.only(left: 4, right: 16, top: 6, bottom: 6),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            child: Icon(Icons.arrow_back, color: c.text, size: 24),
          ),
        ),
        const SizedBox(width: 4),
        // Search input
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.search, color: c.textTertiary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  focusNode: _focusNode,
                  style: TextStyle(color: c.text, fontFamily: 'Outfit-Regular', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search people, posts, communities...',
                    hintStyle: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 15),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onSubmitted: (_) => _handleSearch(),
                ),
              ),
              if (_queryCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: _handleClear,
                  child: Icon(Icons.close, color: c.textTertiary, size: 20),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildResultsView(ThemeColors c) {
    return [
      // Tab bar
      Container(
        color: c.surface,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: c.primary,
          unselectedLabelColor: c.textTertiary,
          indicatorColor: c.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontFamily: 'Outfit-SemiBold', fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit-SemiBold', fontSize: 14),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: c.border.withValues(alpha: 0.3),
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Posts'),
            Tab(text: 'Communities'),
            Tab(text: 'Channels'),
          ],
          onTap: (_) {},
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildUsersList(c),
            _buildPostsList(c),
            _buildCommunitiesList(c),
            _buildChannelsList(c),
          ],
        ),
      ),
    ];
  }

  // ── Users tab ─────────────────────────────────────────────────────────────

  Widget _buildUsersList(ThemeColors c) {
    if (_users.isEmpty) return _buildEmptyState(c, searched: true, type: 'users');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          _loadMoreForTab('users');
        }
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _users.length) return _buildFooterLoader(c);
          return _buildUserItem(_users[i], c);
        },
        padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> item, ThemeColors c) {
    final pic = item['profile_pic'] as String?;
    final username = item['username']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final followers = item['followers_count'] as int? ?? 0;
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _navigateToProfile(item['id'].toString(), _HistoryItem(
        type: 'user',
        id: item['id'].toString(),
        username: username,
        name: name,
        profilePic: pic,
        isVerified: (item['is_verified'] == true || item['is_verified'] == 1),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.transparent,
        child: Row(children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: c.border,
            backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null ? Text(initials, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(username, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              followers > 0 ? '$name · $followers followers' : name,
              style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ])),
        ]),
      ),
    );
  }

  // ── Posts tab ─────────────────────────────────────────────────────────────

  Widget _buildPostsList(ThemeColors c) {
    final currentUserId = ref.watch(authProvider).uid;
    if (_posts.isEmpty) return _buildEmptyState(c, searched: true, type: 'posts');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          _loadMoreForTab('posts');
        }
        return false;
      },
      child: ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _posts.length) return _buildFooterLoader(c);
        final item = _posts[i];
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
            _showPostMenu(postId, userId, extra, c);
          },
        );
      },
      padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  void _showPostMenu(String postId, String userId, Map<String, dynamic> extra, ThemeColors c) {
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

  // ── Communities tab ───────────────────────────────────────────────────────

  Widget _buildCommunitiesList(ThemeColors c) {
    if (_communities.isEmpty) return _buildEmptyState(c, searched: true, type: 'communities');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          _loadMoreForTab('communities');
        }
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _communities.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _communities.length) return _buildFooterLoader(c);
          return _buildCommunityItem(_communities[i], c);
        },
        padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  Widget _buildCommunityItem(Map<String, dynamic> item, ThemeColors c) {
    final pic = item['picture'] as String?;
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString();
    final memberCount = item['member_count'] as int? ?? 0;
    final city = item['city']?.toString();
    final isMember = item['is_member'] == true;
    final passRequired = item['pass_required'] == true;

    return GestureDetector(
      onTap: () => _handleCommunityPress(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.transparent,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: pic != null
                ? CachedNetworkImage(imageUrl: pic, width: 50, height: 50, fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(width: 50, height: 50, color: c.border),
                    errorWidget: (ctx, url, err) => Container(width: 50, height: 50, color: c.border))
                : Container(width: 50, height: 50, color: c.border,
                    child: Icon(Icons.group, color: c.textTertiary, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(description, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 3),
            Text(
              city != null ? '$memberCount ${memberCount == 1 ? 'member' : 'members'} · $city' : '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
              style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12),
            ),
          ])),
          const SizedBox(width: 10),
          if (isMember)
            _buildBadge(c, label: 'Joined', filled: false)
          else if (passRequired)
            _buildBadge(c, label: 'Pass', filled: false, icon: Icons.lock, iconSize: 12)
          else
            _buildBadge(c, label: 'View', filled: false),
        ]),
      ),
    );
  }

  // ── Channels tab ──────────────────────────────────────────────────────────

  Widget _buildChannelsList(ThemeColors c) {
    if (_channels.isEmpty) return _buildEmptyState(c, searched: true, type: 'channels');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
          _loadMoreForTab('channels');
        }
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _channels.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _channels.length) return _buildFooterLoader(c);
          return _buildChannelItem(_channels[i], c);
        },
        padding: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  Widget _buildChannelItem(Map<String, dynamic> item, ThemeColors c) {
    final icon = item['icon'] as String?;
    final name = item['name']?.toString() ?? 'C';
    final description = item['description']?.toString();
    final subs = (item['subscriber_count'] as int? ?? 0);
    final isSubscribed = item['is_subscribed'] == true;
    final isVerified = item['is_verified'] == true || item['is_verified'] == 1;

    return GestureDetector(
      onTap: () => context.push('/channel/${item['id']}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.transparent,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Avatar
          icon != null
              ? CircleAvatar(radius: 25, backgroundImage: CachedNetworkImageProvider(icon), backgroundColor: c.border)
              : CircleAvatar(radius: 25, backgroundColor: c.primary,
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Outfit-Bold', fontSize: 20))),
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
              Text(description, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 3),
            Text('${subs.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} subscribers',
                style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 12)),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _handleChannelSubscribe(item),
            child: _buildBadge(c, label: isSubscribed ? 'Subscribed' : 'Subscribe', filled: false),
          ),
        ]),
      ),
    );
  }

  // ── History ───────────────────────────────────────────────────────────────

  Widget _buildHistoryView(ThemeColors c) {
    final shown = _showAllHistory ? _history : _history.take(7).toList();
    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Recent', style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 16)),
          GestureDetector(
            onTap: _history.length > 7 && !_showAllHistory
                ? () => setState(() => _showAllHistory = true)
                : _clearAllHistory,
            child: Text(
              _history.length > 7 && !_showAllHistory ? 'See all' : 'Clear all',
              style: TextStyle(color: c.primary, fontFamily: 'Outfit-Medium', fontSize: 14),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: shown.length,
          itemBuilder: (_, i) => _buildHistoryItem(shown[i], c),
        ),
      ),
    ]);
  }

  Widget _buildHistoryItem(_HistoryItem item, ThemeColors c) {
    final pic = item.profilePic;
    final label = item.type == 'user' ? (item.username ?? '') : (item.text ?? '');
    final sub = item.type == 'user' ? item.name : null;

    return GestureDetector(
      onTap: () => _handleHistoryItemPress(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.transparent,
        child: Row(children: [
          // Icon / avatar
          if (item.type == 'user' && pic != null)
            CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(pic), backgroundColor: c.border)
          else if (item.type == 'user')
            CircleAvatar(radius: 22, backgroundColor: c.border,
                child: Text((item.username?.isNotEmpty == true ? item.username![0].toUpperCase() : '?'), style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')))
          else
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border)),
              child: Icon(Icons.history, color: c.textTertiary, size: 22),
            ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.text, fontFamily: 'Outfit-Regular', fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null && sub.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
          GestureDetector(
            onTap: () => _removeFromHistory(item.dbId),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, color: c.textTertiary, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeColors c, {required bool searched, String? type}) {
    final icon = searched ? Icons.search_off : Icons.search;
    final title = searched
        ? 'No ${type ?? 'results'} found'
        : 'Search WiTalk';
    final sub = searched
        ? 'Try searching for something else'
        : 'Find people, posts and communities';
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: c.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildFooterLoader(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
        const SizedBox(width: 12),
        Text('Loading more...', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit-Regular', fontSize: 14)),
      ]),
    );
  }

  Widget _buildBadge(ThemeColors c, {required String label, required bool filled, IconData? icon, double iconSize = 12}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? c.primary : Colors.transparent,
        border: Border.all(color: filled ? c.primary : c.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: filled ? Colors.white : c.primary),
          const SizedBox(width: 3),
        ],
        Text(label, style: TextStyle(color: filled ? Colors.white : c.primary, fontFamily: 'Outfit-SemiBold', fontSize: 13)),
      ]),
    );
  }
}
