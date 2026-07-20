import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';

class GroupActionLogScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;
  const GroupActionLogScreen({super.key, required this.groupId, this.groupName});

  @override
  ConsumerState<GroupActionLogScreen> createState() =>
      _GroupActionLogScreenState();
}

class _GroupActionLogScreenState extends ConsumerState<GroupActionLogScreen> {
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchLogs(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore && !_loadingMore) {
      _fetchLogs(reset: false);
    }
  }

  Future<void> _fetchLogs({bool reset = true}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; _offset = 0; _hasMore = true; });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final currentOffset = reset ? 0 : _offset;
      final myUid = ref.read(authProvider).uid;
      final res = await dioClient.get(
        AppEndpoints.groupActionLog(widget.groupId),
        queryParameters: {
          'user_id': myUid,
          'limit': _pageSize,
          'offset': currentOffset,
        },
      );

      final rawData = res.data['data'];
      List<Map<String, dynamic>> items = [];
      if (rawData is List) {
        items = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (rawData is Map && rawData['logs'] is List) {
        items = (rawData['logs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _logs = items;
          } else {
            _logs = [..._logs, ...items];
          }
          _hasMore = items.length >= _pageSize;
          _offset = currentOffset + items.length;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action Log',
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18)),
            if (widget.groupName != null)
              Text(widget.groupName!,
                  style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.text),
            onPressed: () => _fetchLogs(reset: true),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _buildError(c)
              : _logs.isEmpty
                  ? _buildEmpty(c)
                  : _buildList(c),
    );
  }

  Widget _buildList(ThemeColors c) {
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _logs.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 0.5,
        color: c.border.withOpacity(0.4),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (ctx, i) {
        if (i == _logs.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: c.primary)),
          );
        }
        return _LogItem(log: _logs[i], c: c);
      },
    );
  }

  Widget _buildEmpty(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 56, color: c.textTertiary),
        const SizedBox(height: 12),
        Text('No moderation actions yet',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16)),
        const SizedBox(height: 6),
        Text('Bans, kicks, and deleted messages will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
      ]),
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text(_error ?? 'Failed to load action log',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _fetchLogs(reset: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: const Text('Retry', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ]),
    );
  }
}

// ── Action meta ───────────────────────────────────────────────────────────────

class _ActionMeta {
  final IconData icon;
  final Color color;
  final String? badge;
  const _ActionMeta({required this.icon, required this.color, this.badge});
}

_ActionMeta _getMeta(String type) {
  switch (type) {
    case 'member_banned':
      return const _ActionMeta(icon: Icons.block, color: Color(0xFFEF4444));
    case 'member_kicked':
      return const _ActionMeta(icon: Icons.person_remove_outlined, color: Color(0xFFF59E0B));
    case 'message_deleted':
      return const _ActionMeta(icon: Icons.delete_outlined, color: Color(0xFF6366F1));
    case 'admin_appointed':
      return const _ActionMeta(icon: Icons.security_outlined, color: Color(0xFF10B981));
    case 'admin_removed':
      return const _ActionMeta(icon: Icons.remove_moderator_outlined, color: Color(0xFF9CA3AF));
    case 'adda_kicked':
      return const _ActionMeta(icon: Icons.logout, color: Color(0xFFF97316), badge: 'Adda');
    case 'adda_banned':
      return const _ActionMeta(icon: Icons.block, color: Color(0xFFDC2626), badge: 'Adda');
    case 'adda_muted':
      return const _ActionMeta(icon: Icons.mic_off_outlined, color: Color(0xFF8B5CF6), badge: 'Adda');
    case 'adda_community_kicked':
      return const _ActionMeta(icon: Icons.group_remove_outlined, color: Color(0xFFEA580C), badge: 'Community');
    case 'adda_community_banned':
      return const _ActionMeta(icon: Icons.person_off_outlined, color: Color(0xFFB91C1C), badge: 'Community');
    case 'member_muted':
      return const _ActionMeta(icon: Icons.volume_off_outlined, color: Color(0xFFF59E0B));
    case 'member_unmuted':
      return const _ActionMeta(icon: Icons.volume_up_outlined, color: Color(0xFF10B981));
    case 'member_unbanned':
      return const _ActionMeta(icon: Icons.check_circle_outlined, color: Color(0xFF10B981));
    case 'adda_terminated':
      return const _ActionMeta(icon: Icons.stop_circle_outlined, color: Color(0xFFEF4444), badge: 'Adda');
    default:
      return const _ActionMeta(icon: Icons.info_outline, color: Color(0xFF9CA3AF));
  }
}

String _timeAgo(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

// ── Log item widget ───────────────────────────────────────────────────────────

class _LogItem extends StatelessWidget {
  final Map<String, dynamic> log;
  final ThemeColors c;

  const _LogItem({required this.log, required this.c});

  @override
  Widget build(BuildContext context) {
    final type = log['action_type'] as String? ?? '';
    final meta = _getMeta(type);

    final actorName = log['actor_name'] as String? ?? log['actor_username'] as String? ?? 'Unknown';
    final actorPic = log['actor_avatar'] as String?;
    final targetName = log['target_name'] as String?;
    final timestamp = _timeAgo(log['created_at'] as String?);
    final metadata = log['metadata'] as Map<String, dynamic>?;

    // Build action verb + trailing text
    String verb = '';
    String? trailing;
    switch (type) {
      case 'admin_appointed': verb = 'appointed'; break;
      case 'admin_removed': verb = 'removed'; break;
      case 'member_kicked': verb = 'removed'; break;
      case 'member_banned': verb = 'banned'; break;
      case 'member_muted': verb = 'muted'; break;
      case 'member_unmuted': verb = 'unmuted'; break;
      case 'member_unbanned': verb = 'unbanned'; break;
      case 'message_deleted': verb = 'deleted a message'; break;
      case 'adda_terminated': verb = 'terminated the adda'; break;
      case 'adda_kicked': verb = 'kicked from adda'; break;
      case 'adda_banned': verb = 'banned from adda'; break;
      case 'adda_muted': verb = 'muted in adda'; break;
      case 'adda_community_kicked': verb = 'kicked from community'; break;
      case 'adda_community_banned': verb = 'banned from community'; break;
      default: verb = type.replaceAll('_', ' ');
    }

    // Duration for mute actions
    final durationMap = {
      '1_hour': '1 hour', '1_day': '1 day', '7_days': '7 days', 'permanent': 'permanently',
    };
    if ((type == 'member_muted' || type == 'adda_muted') && metadata?['duration'] != null) {
      final dur = metadata!['duration'] as String;
      trailing = 'for ${durationMap[dur] ?? dur}';
    }

    // Reason for bans
    if (['member_banned', 'adda_banned', 'adda_community_banned', 'adda_community_kicked']
            .contains(type) &&
        metadata?['reason'] != null) {
      trailing = '· "${metadata!['reason']}"';
    }

    // Perm badges for admin_appointed
    List<String> permBadges = [];
    if (type == 'admin_appointed' && metadata != null) {
      if (metadata['can_ban'] == true) permBadges.add('Ban');
      if (metadata['can_kick'] == true) permBadges.add('Kick');
      if (metadata['can_mute'] == true) permBadges.add('Mute');
      if (metadata['can_appoint_admin'] == true) permBadges.add('Appoint');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action icon circle
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: 20, color: meta.color),
          ),
          const SizedBox(width: 12),
          // Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Actor avatar
                    actorPic != null
                        ? CircleAvatar(
                            radius: 14,
                            backgroundImage: CachedNetworkImageProvider(actorPic),
                          )
                        : CircleAvatar(
                            radius: 14,
                            backgroundColor: c.border,
                            child: Icon(Icons.person, size: 14, color: c.textSecondary),
                          ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: actorName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' $verb'),
                            if (targetName != null && type != 'message_deleted')
                              TextSpan(
                                text: ' $targetName',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.primary,
                                ),
                              ),
                            if (type == 'message_deleted' && targetName != null)
                              TextSpan(
                                children: [
                                  const TextSpan(text: ' by '),
                                  TextSpan(
                                    text: targetName,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: c.primary),
                                  ),
                                ],
                              ),
                            if (trailing != null)
                              TextSpan(
                                text: ' $trailing',
                                style: TextStyle(color: c.textSecondary, fontSize: 12),
                              ),
                            if (permBadges.isNotEmpty)
                              TextSpan(
                                text: ' (${permBadges.join(', ')})',
                                style: TextStyle(color: c.textSecondary, fontSize: 12),
                              ),
                            if (meta.badge != null)
                              TextSpan(
                                text: ' [${meta.badge}]',
                                style: TextStyle(color: meta.color, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    timestamp,
                    style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
