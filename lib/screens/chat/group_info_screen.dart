import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../api/upload_service.dart';
import '../../services/chat_api_service.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _myUid;
  bool _isAdmin = false;
  bool _isOwner = false;

  // Edit mode
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _myUid = ref.read(authProvider).uid;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await chatApiService.getGroupDetail(widget.groupId);
      if (detail == null) throw Exception('Not found');

      final membersList = (detail['members'] as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

      final me = membersList.firstWhere(
        (m) =>
            m['user_id']?.toString() == _myUid ||
            m['id']?.toString() == _myUid,
        orElse: () => {},
      );

      if (mounted) {
        setState(() {
          _group = detail;
          _members = membersList;
          _isAdmin = me['role'] == 'admin' || me['role'] == 'moderator';
          _isOwner =
              me['role'] == 'owner' || detail['owner_id']?.toString() == _myUid;
          _nameCtrl.text = detail['name'] as String? ?? '';
          _descCtrl.text = detail['description'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  bool get _canEdit => _isAdmin || _isOwner;

  String _roleBadge(String? role) {
    if (role == 'owner') return 'Owner';
    if (role == 'admin' || role == 'moderator') return 'Admin';
    return '';
  }

  Color _roleBadgeColor(String? role, ThemeColors c) {
    if (role == 'owner') return c.warning;
    if (role == 'admin' || role == 'moderator') return c.primary;
    return Colors.transparent;
  }

  Future<void> _copyInviteLink() async {
    final code = _group?['invite_code'] as String?;
    if (code == null) return;
    final link = 'https://witalk.app/group/invite/$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied', style: TextStyle(fontFamily: 'Outfit')),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() { _pendingImagePath = file.path; });
  }

  Future<void> _saveEdit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      String? imageUrl = _group?['image'] as String?;
      if (_pendingImagePath != null) {
        final url = await UploadService.uploadFile(File(_pendingImagePath!));
        if (url != null) imageUrl = url;
      }

      await chatApiService.updateGroup(widget.groupId, {
        'name': name,
        'description': _descCtrl.text.trim(),
        if (imageUrl != null) 'image': imageUrl,
      });

      setState(() {
        _group = {
          ...?_group,
          'name': name,
          'description': _descCtrl.text.trim(),
          if (imageUrl != null) 'image': imageUrl,
        };
        _editing = false;
        _pendingImagePath = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save', style: TextStyle(fontFamily: 'Outfit'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleTopics() async {
    final enabled = _group?['topics_enabled'] == true;
    try {
      await dioClient.post(AppEndpoints.groupTopicsToggle(widget.groupId),
          data: {'enabled': !enabled});
      setState(() {
        _group = {...?_group, 'topics_enabled': !enabled};
      });
    } catch (_) {}
  }

  Future<void> _confirmLeave() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Leave Group?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text('You will no longer receive messages from this group.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Leave', style: TextStyle(color: c.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await chatApiService.leaveGroup(widget.groupId);
        if (mounted) { context.pop(); context.pop(); }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to leave group', style: TextStyle(fontFamily: 'Outfit'))),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete Group?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text('This action is permanent and cannot be undone.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: c.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await chatApiService.deleteGroup(widget.groupId);
        if (mounted) { context.pop(); context.pop(); context.pop(); }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete group', style: TextStyle(fontFamily: 'Outfit'))),
        );
      }
    }
  }

  void _showMemberActions(Map<String, dynamic> member) {
    final c = context.colors;
    final memberId = (member['user_id'] ?? member['id'])?.toString() ?? '';
    if (memberId == _myUid) return;
    final role = member['role'] as String?;
    final isAdminOrMod = role == 'admin' || role == 'moderator' || role == 'owner';

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(member['name'] as String? ?? '',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            const Divider(height: 1),
            if (_isOwner && !isAdminOrMod)
              _ActionTile(
                icon: Icons.shield_outlined,
                label: 'Promote to Admin',
                color: c.primary,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await chatApiService.promoteGroupMember(widget.groupId, memberId);
                    await _load();
                  } catch (_) {}
                },
              ),
            if (_isOwner && isAdminOrMod && role != 'owner')
              _ActionTile(
                icon: Icons.shield_moon_outlined,
                label: 'Demote to Member',
                color: c.warning,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await chatApiService.demoteGroupMember(widget.groupId, memberId);
                    await _load();
                  } catch (_) {}
                },
              ),
            _ActionTile(
              icon: Icons.volume_off_outlined,
              label: 'Mute Member',
              color: c.textSecondary,
              onTap: () async {
                Navigator.pop(ctx);
                await _showMuteDurationPicker(memberId);
              },
            ),
            _ActionTile(
              icon: Icons.person_remove_outlined,
              label: 'Remove from Group',
              color: c.error,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await chatApiService.removeGroupMember(widget.groupId, memberId);
                  await _load();
                } catch (_) {}
              },
            ),
            _ActionTile(
              icon: Icons.block,
              label: 'Ban Member',
              color: c.danger,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await chatApiService.banGroupMember(widget.groupId, memberId, null);
                  await _load();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showMuteDurationPicker(String memberId) async {
    final c = context.colors;
    final options = ['5m', '30m', '1h', '6h', '24h'];
    final labels = ['5 minutes', '30 minutes', '1 hour', '6 hours', '24 hours'];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Mute Duration',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...List.generate(options.length, (i) => ListTile(
              title: Text(labels[i], style: TextStyle(color: c.text, fontFamily: 'Outfit')),
              onTap: () => Navigator.pop(ctx, options[i]),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen != null) {
      try {
        await chatApiService.muteGroupMember(widget.groupId, memberId, chosen);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Member muted for $chosen', style: const TextStyle(fontFamily: 'Outfit'))),
        );
      } catch (_) {}
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
          onPressed: () => _editing ? setState(() { _editing = false; _pendingImagePath = null; }) : context.pop(),
        ),
        title: Text(
          _editing ? 'Edit Group' : 'Group Info',
          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          if (_canEdit && !_editing)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: c.text),
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing)
            _saving
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                  )
                : TextButton(
                    onPressed: _saveEdit,
                    child: Text('Save', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _ErrorState(c: c, onRetry: _load)
              : _buildBody(c),
    );
  }

  Widget _buildBody(ThemeColors c) {
    final name = _group?['name'] as String? ?? '';
    final desc = _group?['description'] as String? ?? '';
    final pic = _group?['image'] as String?;
    final memberCount = _group?['member_count'] ?? _members.length;
    final onlineCount = _group?['online_count'] ?? 0;
    final topicsEnabled = _group?['topics_enabled'] == true;
    final isPublic = _group?['is_public'] == true;

    final displayPic = _pendingImagePath != null ? null : pic;

    return ListView(
      children: [
        // ── Avatar & header ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(children: [
            GestureDetector(
              onTap: _editing ? _pickImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: c.border,
                    backgroundImage: _pendingImagePath != null
                        ? FileImage(File(_pendingImagePath!)) as ImageProvider
                        : displayPic != null
                            ? CachedNetworkImageProvider(displayPic)
                            : null,
                    child: (_pendingImagePath == null && displayPic == null)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: c.text, fontSize: 32, fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  if (_editing)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_editing) ...[
              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Group description (optional)',
                  hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                ),
              ),
            ] else ...[
              Text(name, style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isPublic ? 'Public' : 'Private',
                      style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ]),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc, textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
              ],
              const SizedBox(height: 8),
              Text(
                onlineCount > 0
                    ? '$memberCount members  •  $onlineCount online'
                    : '$memberCount members',
                style: TextStyle(color: c.textTertiary, fontSize: 13, fontFamily: 'Outfit'),
              ),
            ],
          ]),
        ),

        // ── Actions row ────────────────────────────────────────────────────
        if (!_editing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.link,
                  label: 'Invite Link',
                  c: c,
                  onTap: _copyInviteLink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.push_pin_outlined,
                  label: 'Pinned',
                  c: c,
                  onTap: () => context.push('/chat/group-pinned/${widget.groupId}'),
                ),
              ),
              if (_canEdit) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.build_outlined,
                    label: 'Tools',
                    c: c,
                    onTap: () => context.push('/chat/group-tools/${widget.groupId}'),
                  ),
                ),
              ],
            ]),
          ),

        const SizedBox(height: 8),
        Divider(color: c.border, height: 1),

        // ── Admin toggles ──────────────────────────────────────────────────
        if (_canEdit && !_editing) ...[
          _SectionHeader(label: 'Group Settings', c: c),
          SwitchListTile(
            value: topicsEnabled,
            onChanged: (_) => _toggleTopics(),
            activeColor: c.primary,
            title: Text('Topics', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            subtitle: Text('Enable topic-based discussions', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
          ),
          ListTile(
            leading: Icon(Icons.security_outlined, color: c.textSecondary),
            title: Text('Permissions', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
            trailing: Icon(Icons.chevron_right, color: c.textTertiary),
            onTap: () => context.push('/chat/group-permissions/${widget.groupId}'),
          ),
          ListTile(
            leading: Icon(Icons.history_outlined, color: c.textSecondary),
            title: Text('Action Log', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
            trailing: Icon(Icons.chevron_right, color: c.textTertiary),
            onTap: () => context.push('/chat/group-action-log/${widget.groupId}'),
          ),
          Divider(color: c.border, height: 1),
        ],

        // ── Members ────────────────────────────────────────────────────────
        _SectionHeader(label: '${_members.length} Members', c: c),
        ..._members.map((m) {
          final mName = m['name'] as String? ?? m['username'] as String? ?? '';
          final mPic = m['profile_pic'] as String? ?? m['avatar'] as String?;
          final mId = (m['user_id'] ?? m['id'])?.toString() ?? '';
          final mRole = m['role'] as String?;
          final mOnline = m['is_online'] == true;
          final badge = _roleBadge(mRole);
          final badgeColor = _roleBadgeColor(mRole, c);

          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: c.border,
                  backgroundImage: mPic != null ? CachedNetworkImageProvider(mPic) : null,
                  child: mPic == null
                      ? Text(mName.isNotEmpty ? mName[0].toUpperCase() : '?',
                          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                      : null,
                ),
                if (mOnline)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: c.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(mName,
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: mId == _myUid
                ? Text('You', style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12))
                : null,
            trailing: badge.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge,
                        style: TextStyle(color: badgeColor, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  )
                : null,
            onTap: () => context.push('/user/$mId'),
            onLongPress: (_canEdit && mId != _myUid) ? () => _showMemberActions(m) : null,
          );
        }),

        Divider(color: c.border, height: 24),

        // ── Leave / Delete ─────────────────────────────────────────────────
        ListTile(
          leading: Icon(Icons.exit_to_app, color: c.error),
          title: Text('Leave Group', style: TextStyle(color: c.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          onTap: _confirmLeave,
        ),
        if (_isOwner)
          ListTile(
            leading: Icon(Icons.delete_outline, color: c.danger),
            title: Text('Delete Group', style: TextStyle(color: c.danger, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            onTap: _confirmDelete,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeColors c;
  const _SectionHeader({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(label.toUpperCase(),
          style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors c;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Column(children: [
          Icon(icon, color: c.primary, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ThemeColors c;
  final VoidCallback onRetry;
  const _ErrorState({required this.c, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load group info', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
