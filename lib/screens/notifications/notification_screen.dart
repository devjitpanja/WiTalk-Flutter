import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/notification_provider.dart';

// Groups notifications into time-bucketed sections identical to the RN app.
List<Map<String, dynamic>> _groupByTime(List<NotificationItem> notifications) {
  final now = DateTime.now();
  final today = <NotificationItem>[];
  final yesterday = <NotificationItem>[];
  final last7Days = <NotificationItem>[];
  final last30Days = <NotificationItem>[];
  final older = <NotificationItem>[];

  for (final n in notifications) {
    if (n.createdAt == null) {
      older.add(n);
      continue;
    }
    // Backend stores as MySQL DATETIME string in UTC: "2025-01-15 10:30:00"
    final raw = n.createdAt!.replaceFirst(' ', 'T');
    final date = DateTime.tryParse(raw)?.toLocal() ?? now;
    final diffDays = now.difference(date).inDays;

    if (diffDays == 0) {
      today.add(n);
    } else if (diffDays == 1) {
      yesterday.add(n);
    } else if (diffDays <= 7) {
      last7Days.add(n);
    } else if (diffDays <= 30) {
      last30Days.add(n);
    } else {
      older.add(n);
    }
  }

  return [
    if (today.isNotEmpty) {'title': 'Today', 'data': today},
    if (yesterday.isNotEmpty) {'title': 'Yesterday', 'data': yesterday},
    if (last7Days.isNotEmpty) {'title': 'Last 7 days', 'data': last7Days},
    if (last30Days.isNotEmpty) {'title': 'Last 30 days', 'data': last30Days},
    if (older.isNotEmpty) {'title': 'Older', 'data': older},
  ];
}

// Flattens grouped sections into a list of typed items for ListView
List<_FlatItem> _flatten(List<Map<String, dynamic>> groups) {
  final result = <_FlatItem>[];
  for (final g in groups) {
    result.add(_FlatItem.header(g['title'] as String));
    for (final n in g['data'] as List<NotificationItem>) {
      result.add(_FlatItem.notification(n));
    }
  }
  return result;
}

class _FlatItem {
  final bool isHeader;
  final String? title;
  final NotificationItem? notification;

  const _FlatItem.header(this.title)
      : isHeader = true,
        notification = null;

  const _FlatItem.notification(this.notification)
      : isHeader = false,
        title = null;
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final _scrollController = ScrollController();

  // Tracks which notifications have been auto-marked via scroll
  final _markedSet = <String>{};
  Timer? _batchMarkTimer;
  final _pendingMarks = <String>{};

  // Alert dialogs
  bool _deleteAlertVisible = false;
  String? _deleteTargetId;
  bool _infoAlertVisible = false;
  String _infoTitle = '';
  String _infoMessage = '';
  String _infoType = 'info';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Mark all as seen when screen opens (matches RN useEffect on mount)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).markAllAsSeen();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _batchMarkTimer?.cancel();
    if (_pendingMarks.isNotEmpty) {
      debugPrint('[NotifScreen] dispose: flushing ${_pendingMarks.length} pending marks: $_pendingMarks');
      final notifier = ref.read(notificationProvider.notifier);
      for (final id in _pendingMarks) {
        notifier.markAsRead(id);
      }
      _pendingMarks.clear();
    } else {
      debugPrint('[NotifScreen] dispose: no pending marks to flush');
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  void _scheduleMarkAsRead(String id) {
    if (_markedSet.contains(id)) return;
    debugPrint('[NotifScreen] scheduleMarkAsRead: queuing id=$id (pendingCount=${_pendingMarks.length + 1})');
    _markedSet.add(id);
    _pendingMarks.add(id);

    _batchMarkTimer?.cancel();
    _batchMarkTimer = Timer(const Duration(seconds: 1), () {
      final ids = Set<String>.from(_pendingMarks);
      _pendingMarks.clear();
      debugPrint('[NotifScreen] batchTimer fired: marking ${ids.length} notifications as read: $ids');
      for (final id in ids) {
        ref.read(notificationProvider.notifier).markAsRead(id);
      }
    });
  }

  Future<void> _handleNotificationPress(NotificationItem notif) async {
    if (!notif.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notif.id);
    }
    final result = await _handleNavigation(notif);
    if (result != null && mounted) {
      setState(() {
        _infoTitle = result['title'] as String;
        _infoMessage = result['message'] as String;
        _infoType = (result['type'] as String?) ?? 'info';
        _infoAlertVisible = true;
      });
    }
  }

  void _handleProfilePress(NotificationItem notif) {
    if (notif.actorName == 'WiTalk' || notif.actorName == 'WiTalk Team') return;
    if (!notif.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notif.id);
    }
    if (notif.actorId != null) {
      context.push('/user/${notif.actorId}');
    }
  }

  void _handleDeleteRequest(String id) {
    setState(() {
      _deleteTargetId = id;
      _deleteAlertVisible = true;
    });
  }

  void _confirmDelete() {
    if (_deleteTargetId != null) {
      ref.read(notificationProvider.notifier).deleteNotification(_deleteTargetId!);
    }
    setState(() {
      _deleteTargetId = null;
      _deleteAlertVisible = false;
    });
  }

  // Returns alert data map if the notification type should show a dialog instead of navigating.
  Future<Map<String, dynamic>?> _handleNavigation(NotificationItem notif) async {
    final type = notif.type;
    final referenceId = notif.referenceId?.toString();
    final referenceType = notif.referenceType;
    final actorId = notif.actorId;
    final data = notif.data;

    switch (type) {
      case 'follow':
        if (actorId != null) context.push('/user/$actorId');
        break;

      case 'post':
        {
          final suffix = data?['suffix'] ?? data?['postSuffix'];
          final postId = data?['postId'];
          if (suffix != null) {
            context.push('/post-view/$suffix');
          } else if (postId != null) {
            final s = await _fetchSuffix(postId.toString());
            if (!mounted) break;
            context.push('/post-view/${s ?? postId}');
          } else if (referenceId != null) {
            context.push('/post-view/$referenceId');
          }
        }
        break;

      case 'like':
        if (referenceId != null && referenceType == 'post') {
          final postSuffix = data?['postSuffix'];
          if (postSuffix != null) {
            context.push('/post-view/$postSuffix');
          } else {
            final s = await _fetchSuffix(referenceId);
            if (!mounted) break;
            context.push('/post-view/${s ?? referenceId}');
          }
        }
        break;

      case 'comment':
      case 'comment_reply':
        {
          final postSuffix = data?['postSuffix'];
          final postId = data?['postId']?.toString();
          final commentId = referenceType == 'comment' ? referenceId : null;
          if (postSuffix != null) {
            final path = commentId != null
                ? '/post-view/$postSuffix?commentId=$commentId'
                : '/post-view/$postSuffix';
            context.push(path);
          } else if (postId != null) {
            final s = await _fetchSuffix(postId);
            if (!mounted) break;
            final suffix = s ?? postId;
            final path = commentId != null
                ? '/post-view/$suffix?commentId=$commentId'
                : '/post-view/$suffix';
            context.push(path);
          }
        }
        break;

      case 'mention':
        {
          final suffix = data?['suffix'];
          if (suffix != null) {
            context.push('/post-view/$suffix');
          } else if (referenceId != null) {
            context.push('/post-view/$referenceId');
          }
        }
        break;

      case 'profile_like':
        context.go('/chat');
        break;

      case 'post_removed':
        {
          final reason = (data?['reason'] as String?) ?? 'Policy violation';
          final content = (data?['postContent'] as String?) ?? '';
          final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;
          return {
            'title': 'Post Removed',
            'message':
                'Your post has been removed by our moderation team.\n\nReason: $reason${content.isNotEmpty ? '\n\nPost: "$preview"' : ''}',
            'type': 'warning',
          };
        }

      case 'verification_approved':
        context.push('/profile');
        break;

      case 'verification_rejected':
        context.push('/id-verification');
        break;

      case 'rank_refresh':
        context.push('/rank');
        break;

      case 'group_join_approved':
      case 'group_member_added':
        if (referenceId != null) context.push('/chat/group/$referenceId');
        break;

      case 'message_reaction':
        if (referenceId != null && referenceType == 'conversation') {
          context.push('/chat/conversation/$referenceId');
        }
        break;

      case 'avatar_frame':
        context.push('/profile');
        break;

      case 'pass':
        context.push('/profile');
        break;

      case 'adda':
        {
          final roomId = data?['room_id']?.toString() ?? referenceId;
          if (roomId != null) context.push('/live-audio/$roomId');
        }
        break;

      case 'streak_reminder':
        context.go('/adda');
        break;

      case 'wallet':
        context.push('/wallet');
        break;

      case 'system':
        break;
    }
    return null;
  }

  Future<String?> _fetchSuffix(String postId) async {
    try {
      final res = await dioClient.get('/v1/posts/$postId');
      final d = res.data;
      if (d?['data']?['suffix'] != null) return d['data']['suffix'] as String;
      if (d?['suffix'] != null) return d['suffix'] as String;
      final posts = d?['posts'] as List?;
      if (posts != null && posts.isNotEmpty) {
        final match = posts.firstWhere(
          (p) => p['id']?.toString() == postId,
          orElse: () => null,
        );
        if (match?['suffix'] != null) return match['suffix'] as String;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(notificationProvider);
    final grouped = _groupByTime(state.notifications);
    final flatItems = _flatten(grouped);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(c, state.unreadCount),
                Expanded(
                  child: state.refreshing && state.notifications.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(color: c.primary))
                      : flatItems.isEmpty && !state.loading
                          ? _buildEmpty(c)
                          : CustomScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              slivers: [
                                CupertinoSliverRefreshControl(
                                  onRefresh: () => ref
                                      .read(notificationProvider.notifier)
                                      .fetchNotifications(isRefresh: true),
                                ),
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index == flatItems.length) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  color: c.primary, strokeWidth: 2)),
                                        );
                                      }
                                      final item = flatItems[index];
                                      if (item.isHeader) {
                                        return _SectionHeader(title: item.title!);
                                      }
                                      final notif = item.notification!;
                                      if (!notif.isRead) _scheduleMarkAsRead(notif.id);
                                      return _SwipeableNotifTile(
                                        key: ValueKey(notif.id),
                                        notif: notif,
                                        onPress: () => _handleNotificationPress(notif),
                                        onProfilePress: () => _handleProfilePress(notif),
                                        onDelete: () => _handleDeleteRequest(notif.id),
                                      );
                                    },
                                    childCount: flatItems.length + (state.loading && state.hasMore ? 1 : 0),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),

            // Delete confirmation dialog
            if (_deleteAlertVisible)
              _AlertOverlay(
                title: 'Delete Notification',
                message:
                    'Are you sure you want to delete this notification? This action cannot be undone.',
                type: 'danger',
                confirmText: 'Delete',
                cancelText: 'Cancel',
                showCancel: true,
                onConfirm: _confirmDelete,
                onCancel: () => setState(() {
                  _deleteAlertVisible = false;
                  _deleteTargetId = null;
                }),
              ),

            // Info alert (post_removed, etc.)
            if (_infoAlertVisible)
              _AlertOverlay(
                title: _infoTitle,
                message: _infoMessage,
                type: _infoType,
                confirmText: 'OK',
                showCancel: false,
                onConfirm: () => setState(() => _infoAlertVisible = false),
                onCancel: () => setState(() => _infoAlertVisible = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c, int unreadCount) {
    return Container(
      decoration: BoxDecoration(
        color: c.headerBackground,
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.arrow_back, color: c.text, size: 24),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: unreadCount > 0
                ? GestureDetector(
                    onTap: () =>
                        ref.read(notificationProvider.notifier).markAllAsRead(),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.done_all, color: c.primary, size: 22),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeColors c) {
    return Center(
      child: Text(
        'No notifications yet',
        style: TextStyle(
          color: c.textTertiary,
          fontSize: 16,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.background,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _SwipeableNotifTile extends StatefulWidget {
  final NotificationItem notif;
  final VoidCallback onPress;
  final VoidCallback onProfilePress;
  final VoidCallback onDelete;

  const _SwipeableNotifTile({
    super.key,
    required this.notif,
    required this.onPress,
    required this.onProfilePress,
    required this.onDelete,
  });

  @override
  State<_SwipeableNotifTile> createState() => _SwipeableNotifTileState();
}

class _SwipeableNotifTileState extends State<_SwipeableNotifTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _dragOffset = 0;
  static const _deleteRevealWidth = 80.0;

  // RN: dark unread=#161b27, light unread=#EBF5FF
  static const _unreadBgDark = Color(0xFF161B27);
  static const _unreadBgLight = Color(0xFFEBF5FF);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(-_deleteRevealWidth, 0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_dragOffset < -40 || d.velocity.pixelsPerSecond.dx < -300) {
      setState(() => _dragOffset = -_deleteRevealWidth);
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  void _animateOut() {
    setState(() => _dragOffset = -MediaQuery.of(context).size.width);
    Future.delayed(const Duration(milliseconds: 300), widget.onDelete);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notif = widget.notif;
    final isUnread = !notif.isRead;
    final bg = isUnread
        ? (isDark ? _unreadBgDark : _unreadBgLight)
        : c.background;

    // ClipRect + Stack mirrors RN's `overflow: 'hidden'` on swipeContainer.
    // Container uses minHeight: 80 so tall text can expand (RN: minHeight: 80).
    return ClipRect(
      child: Stack(
        children: [
          // Delete background — positioned behind swipeable content
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _deleteRevealWidth,
            child: GestureDetector(
              onTap: _animateOut,
              child: Container(
                color: const Color(0xFFFF3B30),
                alignment: Alignment.center,
                child: const Icon(Icons.delete, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Swipeable content
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: GestureDetector(
                onTap: widget.onPress,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(
                      bottom: BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: widget.onProfilePress,
                        child: _buildAvatar(c, notif),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDetails(c, notif, isUnread)),
                      if (notif.thumbnailUrl != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: notif.thumbnailUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (ctx, e, w) => const SizedBox(width: 40, height: 40),
                            ),
                          ),
                        ),
                      ],
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeColors c, NotificationItem notif) {
    final pic = notif.actorProfilePicMedium ?? notif.actorProfilePic;
    final isSystem =
        notif.actorName == 'WiTalk' || notif.actorName == 'WiTalk Team';

    if (pic != null && pic.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: pic,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorWidget: (ctx, e, w) => _placeholderAvatar(c, notif, isSystem),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _placeholderAvatar(c, notif, isSystem),
    );
  }

  Widget _placeholderAvatar(ThemeColors c, NotificationItem notif, bool isSystem) {
    if (isSystem) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          '✓',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    final initial = notif.actorName?.isNotEmpty == true
        ? notif.actorName![0].toUpperCase()
        : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.border,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Outfit',
          color: c.textTertiary,
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeColors c, NotificationItem notif, bool isUnread) {
    final actorName = notif.actorName ?? 'Someone';
    final message = notif.message ?? '';
    final timeStr = notif.createdAt != null
        ? timeago.format(
            DateTime.tryParse(notif.createdAt!.replaceFirst(' ', 'T')) ??
                DateTime.now())
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: actorName,
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  height: 1.43,
                  fontFamily: 'Outfit',
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (message.isNotEmpty) ...[
                const TextSpan(text: ' '),
                TextSpan(
                  text: message,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 14,
                    height: 1.43,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          timeStr,
          style: TextStyle(
            color: c.textTertiary,
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}

// Reusable in-app alert dialog that matches the RN CustomAlertDialog
class _AlertOverlay extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'danger' | 'warning' | 'info'
  final String confirmText;
  final String? cancelText;
  final bool showCancel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AlertOverlay({
    required this.title,
    required this.message,
    required this.type,
    required this.confirmText,
    this.cancelText,
    required this.showCancel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accentColor = switch (type) {
      'danger' => c.danger,
      'warning' => c.warning,
      _ => c.primary,
    };

    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 0.5, color: c.border),
                if (showCancel)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            cancelText ?? 'Cancel',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 17,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(
                          width: 0.5, thickness: 0.5, color: c.border),
                      Expanded(
                        child: TextButton(
                          onPressed: onConfirm,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            confirmText,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onConfirm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
