import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/custom_alert_dialog.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmt(dynamic n) {
  final v = (n is int) ? n : (n is double) ? n.toInt() : int.tryParse('$n') ?? 0;
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}

String? _profileImageUrl(Map<String, dynamic> user) =>
    user['profile_pic_medium'] as String? ?? user['profile_pic'] as String?;

// ─── Screen ───────────────────────────────────────────────────────────────────

class FollowersScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? username;
  final String initialTab;

  const FollowersScreen({
    super.key,
    required this.userId,
    this.username,
    this.initialTab = 'followers',
  });

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> {
  static const _pageSize = 20;

  String _activeTab = 'followers';
  String? _currentUserId;
  Map<String, dynamic>? _userInfo;

  // Lists
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  List<dynamic> _friends = [];

  // Pagination
  int _followersPage = 1, _followingPage = 1, _friendsPage = 1;
  bool _hasMoreFollowers = true, _hasMoreFollowing = true, _hasMoreFriends = true;

  // Loading
  bool _loading = false;
  bool _loadingMore = false;

  // Error
  String? _error;

  // Remove sheet
  Map<String, dynamic>? _selectedUser;
  String? _removeActionType;
  bool _removing = false;
  bool _sheetVisible = false;

  // Alert
  ({bool visible, String title, String message, String type}) _alert =
      (visible: false, title: '', message: '', type: 'info');

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('uid');
    await _fetchUserInfo();
    _fetchActive(1);
  }

  // ── API ─────────────────────────────────────────────────────────────────────

  Future<void> _fetchUserInfo() async {
    try {
      final res = await dioClient.get('/v1/user/${widget.userId}');
      final data = res.data?['data'] ?? res.data;
      if (data is Map && mounted) {
        setState(() => _userInfo = Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _fetchFollowers(int page, {bool isRefresh = false}) async {
    _setListLoading(page);
    try {
      final res = await dioClient.get(
          '/v1/followers/${widget.userId}/followers?page=$page&limit=$_pageSize');
      if (!mounted) return;
      if (res.data?['statusCode'] == 200) {
        final d = res.data['data'] ?? res.data;
        final items = (d['followers'] as List? ?? []);
        final pagination = d['pagination'];
        setState(() {
          if (page == 1 || isRefresh) _followers = items;
          else _followers = [..._followers, ...items];
          _hasMoreFollowers = pagination?['hasNextPage'] == true;
          _followersPage = page;
        });
      }
    } catch (_) {
      if (page == 1 && mounted) setState(() => _error = 'Failed to load followers');
      else _showAlert('Error', 'Failed to load more followers');
    } finally {
      _clearListLoading(page);
    }
  }

  Future<void> _fetchFollowing(int page, {bool isRefresh = false}) async {
    _setListLoading(page);
    try {
      final res = await dioClient.get(
          '/v1/followers/${widget.userId}/following?page=$page&limit=$_pageSize');
      if (!mounted) return;
      if (res.data?['statusCode'] == 200) {
        final d = res.data['data'] ?? res.data;
        final items = (d['following'] as List? ?? []);
        final pagination = d['pagination'];
        setState(() {
          if (page == 1 || isRefresh) _following = items;
          else _following = [..._following, ...items];
          _hasMoreFollowing = pagination?['hasNextPage'] == true;
          _followingPage = page;
        });
      }
    } catch (_) {
      if (page == 1 && mounted) setState(() => _error = 'Failed to load following');
      else _showAlert('Error', 'Failed to load more following');
    } finally {
      _clearListLoading(page);
    }
  }

  Future<void> _fetchFriends(int page, {bool isRefresh = false}) async {
    _setListLoading(page);
    try {
      final res = await dioClient.get(
          '/v1/followers/${widget.userId}/friends?page=$page&limit=$_pageSize');
      if (!mounted) return;
      if (res.data?['statusCode'] == 200) {
        final d = res.data['data'] ?? res.data;
        final items = (d['friends'] as List? ?? []);
        final pagination = d['pagination'];
        setState(() {
          if (page == 1 || isRefresh) _friends = items;
          else _friends = [..._friends, ...items];
          _hasMoreFriends = pagination?['hasNextPage'] == true;
          _friendsPage = page;
        });
      }
    } catch (_) {
      if (page == 1 && mounted) setState(() => _error = 'Failed to load friends');
      else _showAlert('Error', 'Failed to load more friends');
    } finally {
      _clearListLoading(page);
    }
  }

  void _setListLoading(int page) {
    if (!mounted) return;
    if (page == 1) setState(() { _loading = true; _error = null; });
    else setState(() => _loadingMore = true);
  }

  void _clearListLoading(int page) {
    if (!mounted) return;
    if (page == 1) setState(() => _loading = false);
    else setState(() => _loadingMore = false);
  }

  void _fetchActive(int page, {bool isRefresh = false}) {
    switch (_activeTab) {
      case 'followers': _fetchFollowers(page, isRefresh: isRefresh);
      case 'following': _fetchFollowing(page, isRefresh: isRefresh);
      case 'friends':   _fetchFriends(page, isRefresh: isRefresh);
    }
  }

  // ── Tab / Refresh / Load-More ────────────────────────────────────────────────

  void _handleTabChange(String tab) {
    if (_activeTab == tab) return;
    setState(() { _activeTab = tab; _error = null; });
    final needsLoad = (tab == 'followers' && _followers.isEmpty) ||
        (tab == 'following' && _following.isEmpty) ||
        (tab == 'friends' && _friends.isEmpty);
    if (needsLoad) _fetchActive(1);
  }

  Future<void> _handleRefresh() async {
    await _fetchUserInfo();
    _fetchActive(1, isRefresh: true);
  }

  void _handleLoadMore() {
    if (_loadingMore) return;
    switch (_activeTab) {
      case 'followers':
        if (_hasMoreFollowers) _fetchFollowers(_followersPage + 1);
      case 'following':
        if (_hasMoreFollowing) _fetchFollowing(_followingPage + 1);
      case 'friends':
        if (_hasMoreFriends) _fetchFriends(_friendsPage + 1);
    }
  }

  // ── Remove / Unfollow ────────────────────────────────────────────────────────

  void _openRemoveSheet(Map<String, dynamic> user, String type) {
    setState(() {
      _selectedUser = user;
      _removeActionType = type;
      _sheetVisible = true;
    });
  }

  void _closeRemoveSheet() => setState(() => _sheetVisible = false);

  Future<void> _confirmRemove() async {
    if (_selectedUser == null || _removing) return;
    setState(() => _removing = true);
    try {
      if (_removeActionType == 'unfollow') {
        await dioClient.post('/v1/followers/toggle',
            data: {'followingId': _selectedUser!['id'], 'followerId': _currentUserId});
        setState(() {
          _following = _following.where((u) => u['id'] != _selectedUser!['id']).toList();
          if (_userInfo != null) {
            _userInfo = {..._userInfo!, 'following_count': ((_userInfo!['following_count'] ?? 1) - 1).clamp(0, double.infinity).toInt()};
          }
        });
      } else {
        await dioClient.post('/v1/followers/remove',
            data: {'followerIdToRemove': _selectedUser!['id'], 'currentUserId': _currentUserId});
        setState(() {
          _followers = _followers.where((u) => u['id'] != _selectedUser!['id']).toList();
          if (_userInfo != null) {
            _userInfo = {..._userInfo!, 'followers_count': ((_userInfo!['followers_count'] ?? 1) - 1).clamp(0, double.infinity).toInt()};
          }
        });
      }
      _closeRemoveSheet();
    } catch (_) {
      _showAlert('Error', 'Something went wrong. Please try again.');
      _closeRemoveSheet();
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _handleUserPress(Map<String, dynamic> user) {
    final id = user['id'] as String? ?? '';
    if (id == _currentUserId) {
      context.push('/profile');
    } else {
      context.push('/user/$id');
    }
  }

  // ── Alert ────────────────────────────────────────────────────────────────────

  void _showAlert(String title, String message, {String type = 'danger'}) {
    if (!mounted) return;
    setState(() => _alert = (visible: true, title: title, message: message, type: type));
  }

  // ── Current data ─────────────────────────────────────────────────────────────

  List<dynamic> get _currentData => switch (_activeTab) {
    'following' => _following,
    'friends'   => _friends,
    _           => _followers,
  };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOwn = _currentUserId != null &&
        _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(colors),
                _buildTabs(colors),
                Expanded(child: _buildContent(colors, isOwn)),
              ],
            ),
          ),
          if (_sheetVisible) _buildRemoveSheet(colors),
          CustomAlertDialog(
            visible: _alert.visible,
            title: _alert.title,
            message: _alert.message,
            type: _alert.type,
            showCancel: false,
            confirmText: 'OK',
            onConfirm: () => setState(() => _alert = (visible: false, title: '', message: '', type: 'info')),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeColors colors) => Container(
    decoration: BoxDecoration(
      color: colors.headerBackground,
      border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, color: colors.text, size: 24),
          ),
        ),
        Expanded(
          child: Text(
            _userInfo?['name'] as String? ?? widget.username ?? 'User',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 32),
      ],
    ),
  );

  // ── Tabs ─────────────────────────────────────────────────────────────────────

  Widget _buildTabs(ThemeColors colors) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
    ),
    child: Row(
      children: [
        _buildTab('followers', '${_fmt(_userInfo?['followers_count'])} Followers', colors),
        _buildTab('following', '${_fmt(_userInfo?['following_count'])} Following', colors),
        _buildTab('friends', '${_fmt(_userInfo?['friends_count'])} Friends', colors),
      ],
    ),
  );

  Widget _buildTab(String tab, String label, ThemeColors colors) {
    final active = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTabChange(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? colors.primary : colors.textSecondary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────────

  Widget _buildContent(ThemeColors colors, bool isOwn) {
    if (_loading) return _buildLoadingState(colors);
    if (_error != null) return _buildErrorState(colors);
    if (_currentData.isEmpty) return _buildEmptyState(colors);
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: colors.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            _handleLoadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _currentData.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _currentData.length) return _buildFooterLoader(colors);
            return _buildUserItem(_currentData[i] as Map<String, dynamic>, colors, isOwn);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeColors colors) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: colors.primary),
        const SizedBox(height: 12),
        Text(
          'Loading $_activeTab...',
          style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 16),
        ),
      ],
    ),
  );

  Widget _buildErrorState(ThemeColors colors) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.error),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong',
            style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(_error ?? '',
            style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _handleRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Try Again',
                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState(ThemeColors colors) {
    final (icon, title, message) = switch (_activeTab) {
      'followers' => (Icons.people_outline, 'No followers yet', "When people follow this user, they'll appear here."),
      'following' => (Icons.person_add_outlined, 'No following yet', "When this user follows people, they'll appear here."),
      'friends'   => (Icons.people, 'No friends yet', "When this user has mutual followers, they'll appear here as friends."),
      _           => (Icons.people_outline, 'No data', 'Nothing to show here.'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(title,
              style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message,
              style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── User Item ────────────────────────────────────────────────────────────────

  Widget _buildUserItem(Map<String, dynamic> user, ThemeColors colors, bool isOwn) {
    final name = user['name'] as String? ?? 'Unknown User';
    final bio = user['bio'] as String?;
    final pic = _profileImageUrl(user);
    final removeType = _activeTab == 'following' ? 'unfollow'
        : _activeTab == 'followers' ? 'removeFollower'
        : null;

    return GestureDetector(
      onTap: () => _handleUserPress(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            _buildAvatar(pic, name, colors),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOwn && removeType != null)
              GestureDetector(
                onTap: () => _openRemoveSheet(user, removeType),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 20, color: colors.textTertiary),
                ),
              )
            else
              Icon(Icons.chevron_right, size: 24, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String name, ThemeColors colors) {
    Widget child;
    if (url != null && url.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: colors.border),
        errorWidget: (_, __, ___) => _avatarFallback(name, colors),
      );
    } else {
      child = _avatarFallback(name, colors);
    }
    return ClipOval(
      child: SizedBox(width: 50, height: 50, child: child),
    );
  }

  Widget _avatarFallback(String name, ThemeColors colors) => Container(
    color: colors.border,
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
    ),
  );

  Widget _buildFooterLoader(ThemeColors colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('Loading more...', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
      ],
    ),
  );

  // ── Remove Sheet ─────────────────────────────────────────────────────────────

  Widget _buildRemoveSheet(ThemeColors colors) {
    final user = _selectedUser;
    if (user == null) return const SizedBox.shrink();
    final isUnfollow = _removeActionType == 'unfollow';
    final displayName = user['username'] as String? ?? user['name'] as String? ?? 'this user';
    final pic = _profileImageUrl(user);

    return GestureDetector(
      onTap: _closeRemoveSheet,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                color: colors.bottomSheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: pic != null
                              ? CachedNetworkImage(imageUrl: pic, fit: BoxFit.cover)
                              : _avatarFallback(user['name'] as String? ?? '', colors),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUnfollow ? 'Unfollow?' : 'Remove Follower?',
                              style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isUnfollow
                                  ? "We won't tell $displayName you unfollowed them."
                                  : "We won't tell $displayName they were removed from your followers.",
                              style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _removing ? null : _confirmRemove,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: _removing
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colors.error, strokeWidth: 2))
                          : Text(
                              isUnfollow ? 'Unfollow' : 'Remove',
                              style: TextStyle(color: colors.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
