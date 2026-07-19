import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';

class GroupActionLogScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupActionLogScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupActionLogScreen> createState() => _GroupActionLogScreenState();
}

class _GroupActionLogScreenState extends ConsumerState<GroupActionLogScreen> {
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _pageSize = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore && !reset) return;

    if (reset) {
      setState(() { _loading = true; _error = null; _page = 1; _hasMore = true; });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await dioClient.get(
        AppEndpoints.groupActionLog(widget.groupId),
        queryParameters: {'page': reset ? 1 : _page, 'limit': _pageSize},
      );

      final rawData = res.data['data'];
      List<Map<String, dynamic>> items = [];
      if (rawData is List) {
        items = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (rawData is Map && rawData['logs'] is List) {
        items = (rawData['logs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (reset) {
        _logs = items;
        _page = 2;
      } else {
        _logs = [..._logs, ...items];
        _page++;
      }

      _hasMore = items.length >= _pageSize;
    } catch (e) {
      if (reset) _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  // ── Action type metadata ──────────────────────────────────────────────────

  static _ActionMeta _getMeta(String type) {
    switch (type) {
      case 'member_added':
        return const _ActionMeta(icon: Icons.person_add_outlined, label: 'added', colorKey: 'success');
      case 'member_removed':
        return const _ActionMeta(icon: Icons.person_remove_outlined, label: 'removed', colorKey: 'error');
      case 'member_promoted':
        return const _ActionMeta(icon: Icons.shield_outlined, label: 'promoted', colorKey: 'primary');
      case 'member_demoted':
        return const _ActionMeta(icon: Icons.shield_moon_outlined, label: 'demoted', colorKey: 'warning');
      case 'member_banned':
        return const _ActionMeta(icon: Icons.block, label: 'banned', colorKey: 'danger');
      case 'member_muted':
        return const _ActionMeta(icon: Icons.volume_off_outlined, label: 'muted', colorKey: 'warning');
      case 'group_name_changed':
        return const _ActionMeta(icon: Icons.edit_outlined, label: 'changed group name', colorKey: 'primary');
      case 'group_image_changed':
        return const _ActionMeta(icon: Icons.image_outlined, label: 'changed group photo', colorKey: 'primary');
      case 'message_deleted':
        return const _ActionMeta(icon: Icons.delete_outline, label: 'deleted a message', colorKey: 'error');
      case 'message_pinned':
        return const _ActionMeta(icon: Icons.push_pin_outlined, label: 'pinned a message', colorKey: 'accent');
      default:
        return const _ActionMeta(icon: Icons.info_outline, label: 'performed an action', colorKey: 'textSecondary');
    }
  }

  Color _resolveColor(String key, ThemeColors c) {
    switch (key) {
      case 'success': return c.success;
      case 'error': return c.error;
      case 'primary': return c.primary;
      case 'warning': return c.warning;
      case 'danger': return c.danger;
      case 'accent': return c.accent;
      default: return c.textSecondary;
    }
  }

  String _buildDescription(Map<String, dynamic> log, String metaLabel) {
    final actor = _actorName(log);
    final target = _targetName(log);
    if (target.isNotEmpty) return '$actor $metaLabel $target';
    return '$actor $metaLabel';
  }

  String _actorName(Map<String, dynamic> log) {
    final actor = log['actor'] as Map<String, dynamic>?;
    return actor?['name'] as String? ?? actor?['username'] as String? ?? 'Unknown';
  }

  String _targetName(Map<String, dynamic> log) {
    final target = log['target'] as Map<String, dynamic>?;
    return target?['name'] as String? ?? target?['username'] as String? ?? '';
  }

  String _actorPic(Map<String, dynamic> log) {
    final actor = log['actor'] as Map<String, dynamic>?;
    return actor?['profile_pic'] as String? ?? actor?['avatar'] as String? ?? '';
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is String) {
      dt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
        title: Text('Action Log',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.text),
            onPressed: () => _load(reset: true),
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
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _logs.length + (_loadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _logs.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))),
          );
        }

        final log = _logs[i];
        final type = log['action_type'] as String? ?? log['type'] as String? ?? '';
        final meta = _getMeta(type);
        final metaColor = _resolveColor(meta.colorKey, c);
        final description = _buildDescription(log, meta.label);
        final actorPic = _actorPic(log);
        final actorName = _actorName(log);
        final timestamp = _formatTime(log['created_at'] ?? log['timestamp']);

        // Extra detail string (e.g. new name for group_name_changed)
        final details = log['details'] as Map<String, dynamic>?;
        String? extraText;
        if (type == 'group_name_changed' && details != null) {
          final newName = details['new_name'] as String?;
          if (newName != null) extraText = 'New name: "$newName"';
        }
        if (type == 'message_deleted' && details != null) {
          final snippet = details['content_snippet'] as String?;
          if (snippet != null) extraText = '"$snippet"';
        }

        return _LogItem(
          c: c,
          actorPic: actorPic,
          actorName: actorName,
          description: description,
          timestamp: timestamp,
          icon: meta.icon,
          iconColor: metaColor,
          extraText: extraText,
          onActorTap: () {
            final actorId = (log['actor'] as Map<String, dynamic>?)?['id']?.toString();
            if (actorId != null) context.push('/user/$actorId');
          },
        );
      },
    );
  }

  Widget _buildEmpty(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_outlined, size: 64, color: c.textTertiary),
        const SizedBox(height: 12),
        Text('No actions yet', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Admin actions will appear here', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
      ]),
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load action log', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _load(reset: true),
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Log item widget ────────────────────────────────────────────────────────────

class _LogItem extends StatelessWidget {
  final ThemeColors c;
  final String actorPic;
  final String actorName;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color iconColor;
  final String? extraText;
  final VoidCallback onActorTap;

  const _LogItem({
    required this.c,
    required this.actorPic,
    required this.actorName,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    this.extraText,
    required this.onActorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Actor avatar with action icon overlay
        Stack(
          children: [
            GestureDetector(
              onTap: onActorTap,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: c.border,
                backgroundImage: actorPic.isNotEmpty ? CachedNetworkImageProvider(actorPic) : null,
                child: actorPic.isEmpty
                    ? Text(actorName.isNotEmpty ? actorName[0].toUpperCase() : '?',
                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                    : null,
              ),
            ),
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 1.5),
                ),
                child: Icon(icon, size: 11, color: iconColor),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
                children: [
                  TextSpan(
                    text: actorName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: description.substring(actorName.length),
                  ),
                ],
              ),
            ),
            if (extraText != null) ...[
              const SizedBox(height: 4),
              Text(extraText!,
                  style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 3),
            Text(timestamp, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────

class _ActionMeta {
  final IconData icon;
  final String label;
  final String colorKey;
  const _ActionMeta({required this.icon, required this.label, required this.colorKey});
}
