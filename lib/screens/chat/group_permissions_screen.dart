import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_api_service.dart';

class GroupPermissionsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupPermissionsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupPermissionsScreen> createState() =>
      _GroupPermissionsScreenState();
}

class _GroupPermissionsScreenState
    extends ConsumerState<GroupPermissionsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  String? _error;

  // Permission keys → human-readable labels + icons
  static const _permMeta = <String, _PermMeta>{
    'send_messages': _PermMeta(
      label: 'Send Messages',
      subtitle: 'Allow members to send messages',
      icon: Icons.chat_bubble_outline,
    ),
    'send_media': _PermMeta(
      label: 'Send Media',
      subtitle: 'Allow members to send photos and files',
      icon: Icons.image_outlined,
    ),
    'add_members': _PermMeta(
      label: 'Add Members',
      subtitle: 'Allow members to invite others',
      icon: Icons.person_add_outlined,
    ),
    'pin_messages': _PermMeta(
      label: 'Pin Messages',
      subtitle: 'Allow members to pin messages',
      icon: Icons.push_pin_outlined,
    ),
    'change_group_info': _PermMeta(
      label: 'Change Group Info',
      subtitle: 'Allow members to edit name and description',
      icon: Icons.edit_outlined,
    ),
    'create_topics': _PermMeta(
      label: 'Create Topics',
      subtitle: 'Allow members to start new topics',
      icon: Icons.topic_outlined,
    ),
    'use_reactions': _PermMeta(
      label: 'Use Reactions',
      subtitle: 'Allow members to react to messages',
      icon: Icons.emoji_emotions_outlined,
    ),
  };

  late Map<String, bool> _perms;

  @override
  void initState() {
    super.initState();
    _perms = {for (final k in _permMeta.keys) k: true};
    _load();
  }

  Future<void> _load() async {
    final myUid = ref.read(authProvider).uid;
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await chatApiService.getGroupDetail(widget.groupId);
      if (detail != null && myUid != null) {
        final members = (detail['members'] as List? ?? [])
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        final me = members.firstWhere(
          (m) => m['user_id']?.toString() == myUid || m['id']?.toString() == myUid,
          orElse: () => {},
        );
        _canEdit = me['role'] == 'admin' ||
            me['role'] == 'moderator' ||
            me['role'] == 'owner' ||
            detail['owner_id']?.toString() == myUid;
      }

      final p = await chatApiService.getGroupPermissions(widget.groupId);
      if (p != null) {
        for (final k in _permMeta.keys) {
          if (p.containsKey(k)) {
            _perms[k] = p[k] == true;
          }
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await chatApiService.updateGroupPermissions(widget.groupId, Map<String, dynamic>.from(_perms));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions saved', style: TextStyle(fontFamily: 'Outfit')),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save permissions', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text('Group Permissions',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          if (_canEdit && !_loading)
            _saving
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text('Save',
                        style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _buildError(c)
              : _buildBody(c),
    );
  }

  Widget _buildBody(ThemeColors c) {
    return ListView(
      children: [
        // Banner for non-admins
        if (!_canEdit)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.warning.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: c.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Only admins can modify group permissions.',
                    style: TextStyle(color: c.warning, fontFamily: 'Outfit', fontSize: 13)),
              ),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('MEMBER PERMISSIONS',
              style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: _permMeta.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final kv = entry.value;
              final isLast = i == _permMeta.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(kv.value.icon, color: c.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(kv.value.label,
                              style: TextStyle(color: c.text, fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500, fontSize: 15)),
                          Text(kv.value.subtitle,
                              style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                        ]),
                      ),
                      Switch(
                        value: _perms[kv.key] ?? true,
                        onChanged: _canEdit
                            ? (v) => setState(() => _perms[kv.key] = v)
                            : null,
                        activeColor: c.primary,
                        inactiveThumbColor: c.textTertiary,
                      ),
                    ]),
                  ),
                  if (!isLast)
                    Divider(color: c.border, height: 1, indent: 66, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load permissions', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _load,
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _PermMeta {
  final String label;
  final String subtitle;
  final IconData icon;
  const _PermMeta({required this.label, required this.subtitle, required this.icon});
}
