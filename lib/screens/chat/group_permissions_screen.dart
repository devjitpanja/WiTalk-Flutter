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
  String _groupType = 'private';
  bool _topicsEnabled = false;
  String? _error;

  // Permission keys → current value
  final Map<String, bool> _perms = {
    'edit_group_settings': false,
    'send_new_messages': true,
    'add_other_members': false,
    'approve_new_members': true,
    'allow_members_to_post_topics': false,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myUid = ref.read(authProvider).uid;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await chatApiService.getGroupPermissions(widget.groupId, userId: myUid);
      if (data != null) {
        final perms = data['permissions'] as Map<String, dynamic>? ?? {};
        final role = data['userRole'] as String? ?? 'member';
        final gType = data['groupType'] as String? ?? 'private';
        final tEnabled = data['topicsEnabled'] == true;

        _canEdit = role == 'super_admin' || role == 'admin' || role == 'owner';
        _groupType = gType;
        _topicsEnabled = tEnabled;

        for (final k in _perms.keys) {
          if (perms.containsKey(k)) {
            _perms[k] = perms[k] == true || perms[k] == 1;
          }
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _toggle(String key) async {
    if (!_canEdit || _saving) return;

    // Check if disabled
    if (key == 'approve_new_members' && _isPublic) return;
    if (key == 'allow_members_to_post_topics' && (!_isPublic || !_topicsEnabled)) return;

    final newValue = !(_perms[key] ?? false);

    // Optimistic update
    setState(() => _perms[key] = newValue);
    setState(() => _saving = true);

    try {
      await chatApiService.updateGroupPermissions(widget.groupId, {
        key: newValue ? 1 : 0,
      });
    } catch (_) {
      // Revert on error
      if (mounted) setState(() => _perms[key] = !newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update permission', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isPublic => _groupType == 'public';
  String get _label => _isPublic ? 'Community' : 'Group';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              '$_label permissions',
              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
              ),
            )
          else
            const SizedBox(width: 40),
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
        // ── Members can ────────────────────────────────────────────────────────
        _buildSection(c, title: 'Members can:', children: [
          _PermItem(
            c: c,
            icon: Icons.edit_outlined,
            title: 'Edit group settings',
            description: 'This includes the name, icon, description, disappearing message timer, advanced chat privacy and the ability to pin, keep or unkeep messages.',
            value: _perms['edit_group_settings']!,
            enabled: _canEdit,
            onToggle: () => _toggle('edit_group_settings'),
          ),
          _PermItem(
            c: c,
            icon: Icons.chat_bubble_outlined,
            title: 'Send new messages',
            description: null,
            value: _perms['send_new_messages']!,
            enabled: _canEdit,
            onToggle: () => _toggle('send_new_messages'),
          ),
          _PermItem(
            c: c,
            icon: Icons.person_add_outlined,
            title: 'Add other members',
            description: null,
            value: _perms['add_other_members']!,
            enabled: _canEdit,
            onToggle: () => _toggle('add_other_members'),
          ),
          Opacity(
            opacity: (!_isPublic || !_topicsEnabled) ? 0.5 : 1.0,
            child: _PermItem(
              c: c,
              icon: Icons.forum_outlined,
              title: 'Post topics',
              description: !_isPublic
                  ? 'Post topics is only available for public communities.'
                  : !_topicsEnabled
                      ? 'Topics must be enabled for this ${_label.toLowerCase()} before setting member permissions.'
                      : 'When turned on, any member can create new discussion topics. When off, only admins can post topics.',
              value: _perms['allow_members_to_post_topics']!,
              enabled: _canEdit && _isPublic && _topicsEnabled,
              onToggle: () => _toggle('allow_members_to_post_topics'),
            ),
          ),
        ]),

        // ── Admins can ─────────────────────────────────────────────────────────
        _buildSection(c, title: 'Admins can:', children: [
          Opacity(
            opacity: _isPublic ? 0.5 : 1.0,
            child: _PermItem(
              c: c,
              icon: Icons.how_to_reg_outlined,
              title: 'Approve new members',
              description: _isPublic
                  ? 'This option is disabled for ${_label.toLowerCase()}s. Anyone can join without approval.'
                  : 'When turned on, admins must approve anyone who wants to join the ${_label.toLowerCase()}.',
              value: _perms['approve_new_members']!,
              enabled: _canEdit && !_isPublic,
              onToggle: () => _toggle('approve_new_members'),
            ),
          ),
        ]),

        if (!_canEdit)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 20, color: c.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only admins can modify ${_label.toLowerCase()} permissions',
                  style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
                ),
              ),
            ]),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(ThemeColors c, {required String title, required List<Widget> children}) {
    return Container(
      color: c.surface,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              title,
              style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14),
            ),
          ),
          ...children,
        ],
      ),
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

class _PermItem extends StatelessWidget {
  final ThemeColors c;
  final IconData icon;
  final String title;
  final String? description;
  final bool value;
  final bool enabled;
  final VoidCallback onToggle;

  const _PermItem({
    required this.c,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 24, color: c.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16)),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description!,
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.4)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: enabled ? (_) => onToggle() : null,
            activeColor: enabled ? Colors.black : c.textTertiary,
            activeTrackColor: enabled ? Colors.black.withOpacity(0.5) : c.border,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E5EA),
          ),
        ],
      ),
    );
  }
}
