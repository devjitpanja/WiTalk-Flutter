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
import '../../services/muted_groups_service.dart';

// ── Notification preference type ──────────────────────────────────────────────

enum _NotifPref { all, smart, mentionsReplies, muted }

_NotifPref _notifPrefFrom(String? s) {
  switch (s) {
    case 'smart': return _NotifPref.smart;
    case 'mentions_replies': return _NotifPref.mentionsReplies;
    case 'muted': return _NotifPref.muted;
    default: return _NotifPref.all;
  }
}

extension _NotifPrefExt on _NotifPref {
  String get value {
    switch (this) {
      case _NotifPref.all: return 'all';
      case _NotifPref.smart: return 'smart';
      case _NotifPref.mentionsReplies: return 'mentions_replies';
      case _NotifPref.muted: return 'muted';
    }
  }

  String get label {
    switch (this) {
      case _NotifPref.all: return 'Notify';
      case _NotifPref.smart: return 'Smart';
      case _NotifPref.mentionsReplies: return 'Mentions';
      case _NotifPref.muted: return 'Muted';
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifPref.all: return Icons.notifications_outlined;
      case _NotifPref.smart: return Icons.auto_awesome_outlined;
      case _NotifPref.mentionsReplies: return Icons.notifications_active_outlined;
      case _NotifPref.muted: return Icons.notifications_off_outlined;
    }
  }

  Color get color {
    switch (this) {
      case _NotifPref.all: return const Color(0xFF10B981);
      case _NotifPref.smart: return const Color(0xFF6366F1);
      case _NotifPref.mentionsReplies: return const Color(0xFFF59E0B);
      case _NotifPref.muted: return const Color(0xFFEF4444);
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
  bool _uploadingPhoto = false;
  bool _isProcessing = false;
  String? _error;
  String? _myUid;
  String _myRole = 'member'; // 'super_admin' | 'admin' | 'member'

  // Group permissions (member-level toggles from server)
  Map<String, dynamic> _groupPermissions = {
    'edit_group_settings': 0,
    'send_new_messages': 1,
    'add_other_members': 0,
    'approve_new_members': 1,
  };

  // Notification pref
  _NotifPref _notifPref = _NotifPref.all;

  // Disappearing messages
  int? _disappearTimer;
  bool _settingDisappear = false;

  // Group rules
  String? _groupRules;
  bool _savingRules = false;

  // Member search
  bool _memberSearchVisible = false;
  String _memberSearch = '';
  List<Map<String, dynamic>>? _searchResults; // null = not searching
  bool _searchLoading = false;

  // Pagination
  bool _hasMoreMembers = false;
  int _membersPage = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _myUid = ref.read(authProvider).uid;
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) setState(() { _loading = true; _error = null; });
    try {
      // Must pass userId so the backend can return user_role for this caller
      final detail = await chatApiService.getGroupDetail(widget.groupId, userId: _myUid);
      if (detail == null) throw Exception('Not found');

      // Normalize member role values to canonical RN strings
      final membersList = (detail['members'] as List? ?? []).map((m) {
        final member = Map<String, dynamic>.from(m as Map);
        final r = member['role'] as String?;
        if (r == 'owner') member['role'] = 'super_admin';
        if (r == 'moderator') member['role'] = 'admin';
        return member;
      }).toList();

      // Prefer user_role from the response (set when userId is passed).
      // Fallback: search the members list for this user's role.
      String role = detail['user_role'] as String? ?? '';
      if (role.isEmpty) {
        final me = membersList.firstWhere(
          (m) => m['user_id']?.toString() == _myUid || m['id']?.toString() == _myUid,
          orElse: () => {},
        );
        role = me['role'] as String? ?? 'member';
      }
      // Normalize role variants to the canonical RN values
      if (role == 'owner') role = 'super_admin';
      if (role == 'moderator') role = 'admin';

      // Fetch notification preference
      _NotifPref notif = _NotifPref.all;
      try {
        final muteStatus = await mutedGroupsService.checkGroupMuteStatus(
          _myUid!, widget.groupId);
        final pref = (muteStatus?['data'] as Map?)?['notificationPreference'] as String?;
        notif = _notifPrefFrom(pref);
      } catch (_) {}

      // Fetch group permissions (needed to check member-level edit/add perms)
      Map<String, dynamic> fetchedPerms = _groupPermissions;
      try {
        final permData = await chatApiService.getGroupPermissions(widget.groupId, userId: _myUid);
        if (permData != null && permData['permissions'] is Map) {
          fetchedPerms = Map<String, dynamic>.from(permData['permissions'] as Map);
        }
      } catch (_) {}

      // Fetch group rules
      String? rules;
      try {
        final rulesData = await chatApiService.getGroupRules(widget.groupId);
        rules = rulesData?['rules'] as String?;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _group = detail;
          _members = membersList;
          _myRole = role;
          _groupPermissions = fetchedPerms;
          _notifPref = notif;
          _groupRules = rules;
          _disappearTimer = detail['disappearing_messages_timer'] as int?;
          _hasMoreMembers = detail['has_more_members'] == true;
          _membersPage = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // super_admin | admin — controls the full admin section (permissions, banned, tools, etc.)
  bool get _isAdminLevel => _myRole == 'super_admin' || _myRole == 'admin';

  // Mirrors RN canEditGroup(): admins always, members only when edit_group_settings=1
  bool get _canEditGroup =>
      _isAdminLevel ||
      (_groupPermissions['edit_group_settings'] == 1 ||
          _groupPermissions['edit_group_settings'] == true);

  // Mirrors RN canManageMembers(): admins always, members only when add_other_members=1
  bool get _canManageMembers =>
      _isAdminLevel ||
      (_groupPermissions['add_other_members'] == 1 ||
          _groupPermissions['add_other_members'] == true);

  bool get _isOwner => _myRole == 'super_admin';

  bool get _isPublic =>
      _group?['entity_type'] == 'community' ||
      _group?['group_type'] == 'public' ||
      _group?['is_public'] == true;

  String get _label => _isPublic ? 'Community' : 'Group';

  bool _canPromoteDemote() {
    if (_myRole == 'super_admin') return true;
    if (_myRole == 'admin') {
      final me = _members.firstWhere(
        (m) => m['user_id']?.toString() == _myUid || m['id']?.toString() == _myUid,
        orElse: () => {},
      );
      return me['can_appoint_admin'] == true;
    }
    return false;
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _showPhotoOptions() async {
    final c = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(c),
            _SheetTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              c: c,
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            Divider(height: 0.5, color: c.border),
            _SheetTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              c: c,
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final picker = ImagePicker();
    final file = choice == 'camera'
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (file == null || !mounted) return;
    await _uploadPhoto(file.path);
  }

  Future<void> _uploadPhoto(String path) async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await UploadService.uploadFile(File(path));
      if (url != null) {
        await chatApiService.updateGroup(widget.groupId, {'picture': url});
        await _load(showLoader: false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update photo', style: TextStyle(fontFamily: 'Outfit'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Edit group info ────────────────────────────────────────────────────────

  Future<void> _showEditSheet() async {
    final c = context.colors;
    final nameCtrl = TextEditingController(text: _group?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: _group?['description'] as String? ?? '');

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(c),
                  Text(
                    'Edit $_label Info',
                    style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  _inputLabel(c, '$_label Name'),
                  const SizedBox(height: 8),
                  _textField(c, nameCtrl, 'Enter ${_label.toLowerCase()} name', maxLength: 100),
                  const SizedBox(height: 20),
                  _inputLabel(c, 'Description (Optional)'),
                  const SizedBox(height: 8),
                  _textField(c, descCtrl, 'Enter ${_label.toLowerCase()} description',
                      maxLines: 4, maxLength: 500),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        try {
                          await chatApiService.updateGroup(widget.groupId, {
                            'name': name,
                            'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          });
                          await _load(showLoader: false);
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to update group', style: TextStyle(fontFamily: 'Outfit'))),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Notification prefs ────────────────────────────────────────────────────

  Future<void> _showNotifSheet() async {
    final c = context.colors;

    final options = [
      (_NotifPref.all, 'Get notified for every message', false),
      (_NotifPref.smart, 'Skips filler, batches bursts, always notifies for mentions', true),
      (_NotifPref.mentionsReplies, 'Only when someone @mentions or replies to you', false),
      (_NotifPref.muted, 'No notifications from this group', false),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(c),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Notifications',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              ...options.map((o) {
                final pref = o.$1;
                final subtitle = o.$2;
                final recommended = o.$3;
                final selected = _notifPref == pref;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: pref.color.withOpacity(selected ? 0.18 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(pref.icon, color: pref.color, size: 20),
                  ),
                  title: Row(children: [
                    Text(
                      pref == _NotifPref.all ? 'All messages'
                          : pref == _NotifPref.smart ? 'Smart'
                          : pref == _NotifPref.mentionsReplies ? 'Mentions & replies only'
                          : 'Mute',
                      style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                    ),
                    if (recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('RECOMMENDED',
                            style: TextStyle(fontSize: 9, color: Color(0xFF6366F1), fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  subtitle: Text(subtitle,
                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
                  trailing: selected ? Icon(Icons.check, color: pref.color) : null,
                  tileColor: selected ? pref.color.withOpacity(0.06) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (pref == _notifPref) return;
                    try {
                      await mutedGroupsService.setNotificationPreference(
                        _myUid!, widget.groupId, pref.value);
                      if (mounted) setState(() => _notifPref = pref);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to update notification setting', style: TextStyle(fontFamily: 'Outfit'))),
                        );
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Group rules ────────────────────────────────────────────────────────────

  Future<void> _showRulesSheet() async {
    final c = context.colors;
    final rulesCtrl = TextEditingController(text: _groupRules ?? '');

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (ctx2, setSt) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(c),
                    Text('$_label Rules',
                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(
                      'Set rules that all members must follow. Rules are visible to everyone in the ${_label.toLowerCase()}.',
                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _inputLabel(c, 'Rules'),
                    const SizedBox(height: 8),
                    _textField(c, rulesCtrl,
                        'e.g. Be respectful, No spam, No NSFW content...',
                        maxLines: 6, maxLength: 500),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${rulesCtrl.text.length}/500',
                        style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12),
                      ),
                    ),
                    if (rulesCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () { rulesCtrl.clear(); setSt(() {}); },
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                        label: const Text('Clear rules',
                            style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savingRules
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                setState(() => _savingRules = true);
                                try {
                                  final rules = rulesCtrl.text.trim().isEmpty ? null : rulesCtrl.text.trim();
                                  await chatApiService.updateGroupRules(widget.groupId, rules);
                                  if (mounted) setState(() { _groupRules = rules; _savingRules = false; });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Group rules updated', style: TextStyle(fontFamily: 'Outfit'))),
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) setState(() => _savingRules = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save Rules',
                            style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Disappearing messages ─────────────────────────────────────────────────

  static const _disappearOptions = [
    (label: 'Off', seconds: 0),
    (label: '24 Hours', seconds: 86400),
    (label: '7 Days', seconds: 604800),
    (label: '90 Days', seconds: 7776000),
  ];

  String _disappearLabel(int? seconds) {
    if (seconds == null || seconds == 0) return 'Off';
    final opt = _disappearOptions.firstWhere((o) => o.seconds == seconds, orElse: () => (label: 'Off', seconds: 0));
    return opt.label;
  }

  Future<void> _showDisappearSheet() async {
    final c = context.colors;
    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(c),
              Text('Disappearing Messages',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'All messages — including existing ones — will be deleted for everyone after the selected duration.',
                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              ..._disappearOptions.map((opt) {
                final selected = (_disappearTimer == null || _disappearTimer == 0)
                    ? opt.seconds == 0
                    : _disappearTimer == opt.seconds;
                return ListTile(
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: selected ? c.primary : c.text,
                      fontFamily: 'Outfit',
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: selected ? Icon(Icons.check, color: c.primary) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (_settingDisappear) return;
                    setState(() => _settingDisappear = true);
                    try {
                      await chatApiService.setGroupDisappearingMessages(widget.groupId, opt.seconds);
                      if (mounted) {
                        setState(() {
                          _disappearTimer = opt.seconds == 0 ? null : opt.seconds;
                          _settingDisappear = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            opt.seconds == 0
                                ? 'Disappearing messages turned off'
                                : 'Disappearing messages set to ${opt.label}',
                            style: const TextStyle(fontFamily: 'Outfit'),
                          ),
                        ));
                      }
                    } catch (_) {
                      if (mounted) setState(() => _settingDisappear = false);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Invite link ────────────────────────────────────────────────────────────

  Future<void> _copyInviteLink() async {
    final code = _group?['invite_code'] as String?;
    if (code == null) return;
    final link = _isPublic
        ? 'https://witalk.in/$code'
        : 'https://witalk.in/group/$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied to clipboard', style: TextStyle(fontFamily: 'Outfit')),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Member actions ────────────────────────────────────────────────────────

  Future<void> _showMemberActions(Map<String, dynamic> member) async {
    final c = context.colors;
    final memberId = (member['user_id'] ?? member['id'])?.toString() ?? '';
    if (memberId == _myUid) return;

    final mRole = member['role'] as String?;
    final isAdmin = mRole == 'admin';
    final isMember = mRole == 'member' || mRole == null;
    final isMuted = member['is_muted'] == 1 || member['is_muted'] == true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(c),
            // Member header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: c.border,
                    backgroundImage: _memberPic(member) != null
                        ? CachedNetworkImageProvider(_memberPic(member)!)
                        : null,
                    child: _memberPic(member) == null
                        ? Text(
                            (_memberName(member).isNotEmpty ? _memberName(member)[0] : '?').toUpperCase(),
                            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(_memberName(member),
                      style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18)),
                  Text(
                    mRole == 'super_admin' ? 'Owner' : mRole == 'admin' ? (member['admin_title'] as String? ?? 'Admin') : 'Member',
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Promote to admin
            if (_canPromoteDemote() && isMember)
              _SheetTile(
                icon: Icons.security_outlined,
                label: 'Promote to Admin',
                c: c,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showPromoteSheet(member);
                },
              ),

            // Edit admin permissions
            if (_canPromoteDemote() && isAdmin)
              _SheetTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Update Admin Permissions',
                c: c,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showPromoteSheet(member, isEditing: true);
                },
              ),

            // Mute / Unmute — super_admin can act on anyone; admin only on members (not other admins)
            if (_myRole == 'super_admin' ||
                (_myRole == 'admin' && isMember))
              _SheetTile(
                icon: isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                label: isMuted ? 'Unmute Member' : 'Mute Member',
                c: c,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isMuted) {
                    await _confirmUnmute(member, memberId);
                  } else {
                    await _showMuteDurationSheet(memberId, _memberName(member));
                  }
                },
              ),

            // Remove & Ban — only admins/owner
            if (_isAdminLevel) ...[
              _SheetTile(
                icon: Icons.person_remove_outlined,
                label: 'Remove from $_label',
                c: c,
                color: const Color(0xFFEF4444),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmRemoveMember(member, memberId);
                },
              ),

              _SheetTile(
                icon: Icons.block,
                label: 'Ban User',
                c: c,
                color: const Color(0xFFEF4444),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showBanDialog(member, memberId);
                },
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showPromoteSheet(Map<String, dynamic> member, {bool isEditing = false}) async {
    final c = context.colors;
    final mName = _memberName(member);
    final memberId = (member['user_id'] ?? member['id'])?.toString() ?? '';
    final adminTitleCtrl = TextEditingController(text: isEditing ? (member['admin_title'] as String? ?? '') : '');

    Map<String, bool> perms = isEditing
        ? {
            'can_ban': member['can_ban'] == true,
            'can_kick': member['can_kick'] == true,
            'can_appoint_admin': member['can_appoint_admin'] == true,
            'can_mute': member['can_mute'] == true || member['can_mute'] == null,
            'can_end_adda': member['can_end_adda'] == true,
          }
        : {
            'can_ban': true, 'can_kick': true,
            'can_appoint_admin': false,
            'can_mute': true, 'can_end_adda': false,
          };

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx2, setSt) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetHandle(c),
                  Text(
                    isEditing ? 'Update Admin Permissions' : 'Admin Permissions',
                    style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing
                        ? 'Edit what $mName can do as admin'
                        : 'Choose what $mName will be able to do as admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  if (_isOwner) ...[
                    _inputLabel(c, 'Custom title'),
                    const SizedBox(height: 8),
                    _textField(c, adminTitleCtrl,
                        'e.g. Moderator, Co-founder… (leave empty for "Admin")', maxLength: 50),
                    const SizedBox(height: 4),
                    Text(
                      'Shown on their badge instead of "Admin". Only you can set this.',
                      style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ...[
                    _PermToggle(c: c, title: 'Ban members', hint: 'Can permanently ban users from the group', permKey: 'can_ban', perms: perms, setSt: setSt),
                    _PermToggle(c: c, title: 'Kick members', hint: 'Can remove members from the group', permKey: 'can_kick', perms: perms, setSt: setSt),
                    if (_isPublic)
                      _PermToggle(c: c, title: 'Mute members', hint: 'Can mute members (preventing them from chatting or joining the Adda)', permKey: 'can_mute', perms: perms, setSt: setSt),
                    if (_isOwner)
                      _PermToggle(c: c, title: 'Appoint admins', hint: 'Can promote members to admin (max their own permissions)', permKey: 'can_appoint_admin', perms: perms, setSt: setSt),
                    if (_isPublic)
                      _PermToggle(c: c, title: 'End community addas', hint: 'Can terminate any ongoing community adda', permKey: 'can_end_adda', perms: perms, setSt: setSt),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(isEditing ? Icons.admin_panel_settings_outlined : Icons.security_outlined, color: Colors.white, size: 18),
                      label: Text(
                        isEditing ? 'Update Permissions' : 'Confirm & Promote',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);
                        try {
                          final titlePayload = _isOwner && adminTitleCtrl.text.trim().isNotEmpty
                              ? {'admin_title': adminTitleCtrl.text.trim()}
                              : <String, dynamic>{};
                          if (isEditing) {
                            await chatApiService.updateGroupAdminPermissions(
                                widget.groupId, memberId, {...perms, ...titlePayload});
                          } else {
                            await chatApiService.promoteGroupMember(
                                widget.groupId, memberId,
                                permissions: {...perms, ...titlePayload});
                          }
                          await _load(showLoader: false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                isEditing ? '$mName\'s permissions updated' : '$mName promoted to admin',
                                style: const TextStyle(fontFamily: 'Outfit'),
                              ),
                            ));
                          }
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update permissions', style: TextStyle(fontFamily: 'Outfit'))),
                          );
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.remove_moderator_outlined, color: Colors.white, size: 18),
                        label: const Text('Demote to Member',
                            style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() => _isProcessing = true);
                          try {
                            await chatApiService.demoteGroupMember(widget.groupId, memberId);
                            await _load(showLoader: false);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('$mName demoted to member', style: const TextStyle(fontFamily: 'Outfit')),
                            ));
                          } catch (_) {} finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnmute(Map<String, dynamic> member, String memberId) async {
    final mName = _memberName(member);
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Unmute Member', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text('Allow $mName to send messages and join the Adda again?',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unmute', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      await chatApiService.unmuteGroupMember(widget.groupId, memberId);
      await _load(showLoader: false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$mName has been unmuted', style: const TextStyle(fontFamily: 'Outfit'))),
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showMuteDurationSheet(String memberId, String mName) async {
    final c = context.colors;
    final options = [
      (label: '1 Hour', value: '1_hour'),
      (label: '1 Day', value: '1_day'),
      (label: '7 Days', value: '7_days'),
      (label: 'Always', value: 'permanent'),
    ];
    String selected = '1_day';

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx2, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(c),
              Text('Mute $mName',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                "They won't be able to send messages or join the community Adda",
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) => ListTile(
                title: Text(opt.label, style: TextStyle(color: c.text, fontFamily: 'Outfit')),
                trailing: selected == opt.value ? Icon(Icons.check, color: c.primary) : null,
                onTap: () => setSt(() => selected = opt.value),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.volume_off_outlined, color: Colors.white, size: 18),
                    label: const Text('Confirm Mute',
                        style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isProcessing = true);
                      try {
                        await chatApiService.muteGroupMember(widget.groupId, memberId, selected);
                        await _load(showLoader: false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$mName has been muted', style: const TextStyle(fontFamily: 'Outfit'))),
                        );
                      } catch (_) {} finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(Map<String, dynamic> member, String memberId) async {
    final mName = _memberName(member);
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Remove Member', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to remove $mName from the ${_label.toLowerCase()}?',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      await chatApiService.removeGroupMember(widget.groupId, memberId);
      await _load(showLoader: false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$mName removed from ${_label.toLowerCase()}', style: const TextStyle(fontFamily: 'Outfit'))),
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showBanDialog(Map<String, dynamic> member, String memberId) async {
    final mName = _memberName(member);
    final c = context.colors;
    String? banReasonChip;
    final banReasonCtrl = TextEditingController();
    final chips = ['Abusive behaviour', 'Spam', 'Harassment', 'Hate speech', 'Promotion/Ads', 'Other'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ban User',
                      style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 8),
                  Text(
                    'Ban $mName? They will be removed from the ${_label.toLowerCase()}, all their messages will be deleted, and they won\'t be able to rejoin.',
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text('REASON (OPTIONAL)',
                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 12, letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips.map((chip) {
                      final sel = banReasonChip == chip;
                      return GestureDetector(
                        onTap: () => setSt(() => banReasonChip = sel ? null : chip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? c.primary.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? c.primary : c.border),
                          ),
                          child: Text(chip,
                              style: TextStyle(
                                color: sel ? c.primary : c.textSecondary,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  if (banReasonChip == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: banReasonCtrl,
                      maxLines: 2,
                      maxLength: 200,
                      style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe the reason...',
                        hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                        filled: true, fillColor: c.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final reason = banReasonChip == 'Other'
                              ? (banReasonCtrl.text.trim().isNotEmpty ? banReasonCtrl.text.trim() : 'Other')
                              : banReasonChip;
                          setState(() => _isProcessing = true);
                          try {
                            await chatApiService.banGroupMember(widget.groupId, memberId, reason);
                            await _load(showLoader: false);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$mName has been banned from the ${_label.toLowerCase()}',
                                  style: const TextStyle(fontFamily: 'Outfit'))),
                            );
                          } catch (_) {} finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Ban User', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Member search ─────────────────────────────────────────────────────────

  Future<void> _handleMemberSearch(String query) async {
    setState(() => _memberSearch = query);
    if (query.trim().isEmpty) {
      setState(() { _searchResults = null; _searchLoading = false; });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await chatApiService.searchGroupMembers(widget.groupId, query.trim());
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  // ── Load more members ──────────────────────────────────────────────────────

  Future<void> _loadMoreMembers() async {
    if (_loadingMore || !_hasMoreMembers) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _membersPage + 1;
      final detail = await chatApiService.getGroupDetail(widget.groupId);
      if (detail != null) {
        final more = (detail['members'] as List? ?? [])
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        if (mounted) {
          setState(() {
            _members = [..._members, ...more];
            _hasMoreMembers = detail['has_more_members'] == true;
            _membersPage = nextPage;
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Leave / Delete ────────────────────────────────────────────────────────

  Future<void> _confirmLeave() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Leave $_label?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to leave ${_group?['name'] ?? 'this ${_label.toLowerCase()}'}? '
            'You will need an invite code to rejoin.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Color(0xFFFF9800), fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await chatApiService.leaveGroup(widget.groupId);
      if (mounted) {
        // Navigate back to chat list
        context.go('/chat');
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave group', style: TextStyle(fontFamily: 'Outfit'))),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete $_label?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete ${_group?['name']}? This will permanently delete all messages and remove all members. This action cannot be undone.',
          style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await chatApiService.deleteGroup(widget.groupId);
      if (mounted) context.go('/chat');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete group', style: TextStyle(fontFamily: 'Outfit'))),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _memberName(Map<String, dynamic> m) =>
      m['name'] as String? ?? m['username'] as String? ?? '';

  String? _memberPic(Map<String, dynamic> m) =>
      m['profile_pic'] as String? ?? m['avatar'] as String?;

  Widget _sheetHandle(ThemeColors c) => Container(
    width: 40, height: 4,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
  );

  Widget _inputLabel(ThemeColors c, String label) =>
    Text(label, style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14));

  Widget _textField(ThemeColors c, TextEditingController ctrl, String hint,
      {int maxLines = 1, int? maxLength}) =>
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: c.text, fontFamily: 'Outfit'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
        filled: true,
        fillColor: c.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        counterStyle: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 11),
      ),
    );

  // ── Build ─────────────────────────────────────────────────────────────────

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
        title: Text(
          '$_label Info',
          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _buildError(c)
              : Stack(
                  children: [
                    _buildBody(c),
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              CircularProgressIndicator(color: c.primary),
                              const SizedBox(height: 16),
                              Text('Processing...', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16)),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildBody(ThemeColors c) {
    final name = _group?['name'] as String? ?? '';
    final desc = _group?['description'] as String? ?? '';
    final pic = _group?['picture'] as String? ?? _group?['image'] as String?;
    final memberCount = _group?['member_count'] ?? _members.length;
    final topicsEnabled = _group?['topics_enabled'] == true;

    final displayedMembers = _searchResults ?? _members;
    final isAdminView = _myRole == 'super_admin' || _myRole == 'admin';

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Group header ─────────────────────────────────────────────────
          Container(
            color: c.surface,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _canEditGroup ? _showPhotoOptions : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: _canEditGroup ? c.primary : c.border,
                        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                        child: pic == null
                            ? Icon(Icons.group, size: 48, color: Colors.white)
                            : null,
                      ),
                      if (_canEditGroup)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 3),
                            ),
                            child: _uploadingPhoto
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
                    if (_group?['is_verified'] == 1) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF0751DF), size: 22),
                    ],
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit', height: 1.4),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                  style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Edit button — admins always, members only if edit_group_settings=1
                if (_canEditGroup)
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Edit $_label',
                      iconBg: c.primary.withOpacity(0.15),
                      iconColor: c.primary,
                      c: c,
                      onTap: _showEditSheet,
                    ),
                  ),
                if (_canEditGroup) const SizedBox(width: 12),
                // Notification button — always visible to all members
                Expanded(
                  child: _ActionBtn(
                    icon: _notifPref.icon,
                    label: _notifPref.label,
                    iconBg: _notifPref.color.withOpacity(0.15),
                    iconColor: _notifPref.color,
                    c: c,
                    onTap: _showNotifSheet,
                  ),
                ),
                // Add Members — admins always, members only if add_other_members=1
                if (_canManageMembers) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.person_add_outlined,
                      label: 'Add Members',
                      iconBg: const Color(0xFF10B981).withOpacity(0.15),
                      iconColor: const Color(0xFF10B981),
                      c: c,
                      onTap: () => context.push(
                        '/chat/add-group-members/${widget.groupId}',
                        extra: {'existingMemberIds': _members.map((m) => (m['user_id'] ?? m['id'])?.toString() ?? '').toList()},
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Admin section: permissions, banned, action log, tools, topics, disappearing ──
          // Only shown to super_admin and admin — never to regular members
          if (_isAdminLevel) ...[
            Container(
              color: c.surface,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                children: [
                  // Permissions
                  _PermCard(
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: c.primary,
                    title: '$_label permissions',
                    hint: 'Manage member and admin permissions',
                    c: c,
                    onTap: () => context.push('/chat/group-permissions/${widget.groupId}'),
                  ),

                  const SizedBox(height: 12),

                  // Banned users
                  _PermCard(
                    icon: Icons.block,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Banned users',
                    hint: 'View and manage banned users',
                    c: c,
                    onTap: () => context.push('/chat/banned-users/${widget.groupId}'),
                  ),

                  // Action log — only for public/community
                  if (_isPublic) ...[
                    const SizedBox(height: 12),
                    _PermCard(
                      icon: Icons.history_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Action Log',
                      hint: 'View moderation history (bans, kicks, removed messages)',
                      c: c,
                      onTap: () => context.push('/chat/group-action-log/${widget.groupId}'),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Tools
                  _PermCard(
                    icon: Icons.build_outlined,
                    iconColor: c.primary,
                    title: 'Tools',
                    hint: 'Spam protection, welcome message',
                    c: c,
                    onTap: () => context.push('/chat/group-tools/${widget.groupId}'),
                  ),

                  // Topics toggle — community only
                  if (_isPublic) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.forum_outlined,
                              size: 24, color: topicsEnabled ? c.primary : c.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Topics',
                                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                              Text(
                                topicsEnabled ? 'Discussion topics are enabled' : 'Enable topic discussions for this group',
                                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
                              ),
                            ]),
                          ),
                          Switch(
                            value: topicsEnabled,
                            onChanged: (_) async {
                              try {
                                await dioClient.post(
                                  AppEndpoints.groupTopicsToggle(widget.groupId),
                                  data: {'enabled': !topicsEnabled},
                                );
                                if (mounted) {
                                  setState(() => _group = {...?_group, 'topics_enabled': !topicsEnabled});
                                }
                              } catch (_) {}
                            },
                            activeColor: c.primary,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Disappearing messages
                  const SizedBox(height: 12),
                  _PermCard(
                    icon: Icons.timer_outlined,
                    iconColor: (_disappearTimer != null && _disappearTimer != 0) ? c.primary : c.textSecondary,
                    title: 'Disappearing Messages',
                    hint: _disappearTimer != null && _disappearTimer != 0
                        ? 'All messages delete after ${_disappearLabel(_disappearTimer)}'
                        : 'Messages are kept forever',
                    c: c,
                    trailing: Text(
                      _disappearLabel(_disappearTimer),
                      style: TextStyle(color: (_disappearTimer != null && _disappearTimer != 0) ? c.primary : c.textSecondary,
                          fontFamily: 'Outfit', fontSize: 14),
                    ),
                    onTap: _showDisappearSheet,
                  ),
                ],
              ),
            ),
          ],

          // ── Group rules ──────────────────────────────────────────────────
          // Rules section — visible to all members if rules exist; edit button only for canEditGroup
          if (_groupRules != null || _canEditGroup)
            Container(
              color: c.surface,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_label Rules'.toUpperCase(),
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                            fontSize: 14, letterSpacing: 0.5),
                      ),
                      if (_canEditGroup)
                        GestureDetector(
                          onTap: _showRulesSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 16, color: c.primary),
                              const SizedBox(width: 4),
                              Text('Edit', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_groupRules != null && _groupRules!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.gavel_outlined, size: 20, color: c.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_groupRules!,
                                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14, height: 1.5)),
                          ),
                        ],
                      ),
                    )
                  else if (_canEditGroup)
                    GestureDetector(
                      onTap: _showRulesSheet,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.primary.withOpacity(0.3), style: BorderStyle.solid),
                        ),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline, size: 22, color: c.primary),
                          const SizedBox(width: 10),
                          Text('Add ${_label.toLowerCase()} rules',
                              style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),

          // ── Invite link ──────────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite Link'.toUpperCase(),
                  style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                      fontSize: 14, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _copyInviteLink,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 24, color: c.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              'witalk.in/${_isPublic ? '' : 'group/'}${_group?['invite_code'] ?? ''}',
                              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 13),
                            ),
                            Text('Tap to copy full link',
                                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
                          ]),
                        ),
                        Icon(Icons.content_copy, size: 24, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Members section ───────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAdminView
                          ? 'Members (${_group?['member_count'] ?? _members.length})'
                          : 'Owner & Admins',
                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5),
                    ),
                    if (_members.length > 5)
                      GestureDetector(
                        onTap: () {
                          final next = !_memberSearchVisible;
                          setState(() {
                            _memberSearchVisible = next;
                            if (!next) {
                              _memberSearch = '';
                              _searchResults = null;
                            }
                          });
                        },
                        child: Icon(
                          _memberSearchVisible ? Icons.close : Icons.search,
                          size: 20,
                          color: _memberSearchVisible ? c.primary : c.textSecondary,
                        ),
                      ),
                  ],
                ),

                if (!isAdminView) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outlined, size: 14, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Member list is private to protect user privacy',
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12),
                      ),
                    ]),
                  ),
                ],

                if (_memberSearchVisible) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: _handleMemberSearch,
                          ),
                        ),
                        if (_searchLoading) ...[
                          const SizedBox(width: 8),
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                        ],
                        if (_memberSearch.isNotEmpty && !_searchLoading) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() { _memberSearch = ''; _searchResults = null; });
                            },
                            child: Icon(Icons.close, size: 16, color: c.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                ...displayedMembers.map((m) {
                  final mName = _memberName(m);
                  final mPic = _memberPic(m);
                  final mId = (m['user_id'] ?? m['id'])?.toString() ?? '';
                  final mRole = m['role'] as String?;
                  final mUsername = m['username'] as String?;
                  final isMuted = m['is_muted'] == 1 || m['is_muted'] == true;
                  final isOnline = m['is_online'] == true;

                  String? roleBadge;
                  Color? roleBadgeColor;
                  if (mRole == 'super_admin') { roleBadge = 'Owner'; roleBadgeColor = const Color(0xFFFF6B35); }
                  else if (mRole == 'admin') {
                    roleBadge = (m['admin_title'] as String?)?.isNotEmpty == true ? m['admin_title'] as String : 'Admin';
                    roleBadgeColor = const Color(0xFF4ECDC4);
                  }

                  final canShowActions = isAdminView && mId != _myUid && mRole != 'super_admin' &&
                      !(_myRole == 'admin' && mRole == 'admin');

                  return GestureDetector(
                    onTap: () => context.push('/user/$mId'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: c.border,
                                backgroundImage: mPic != null ? CachedNetworkImageProvider(mPic) : null,
                                child: mPic == null
                                    ? Text(
                                        mName.isNotEmpty ? mName[0].toUpperCase() : '?',
                                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                                      )
                                    : null,
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c.surface, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$mName${mId == _myUid ? ' (You)' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: c.text, fontFamily: 'Outfit',
                                            fontWeight: FontWeight.w500, fontSize: 15),
                                      ),
                                    ),
                                    if (roleBadge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleBadgeColor!,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(roleBadge,
                                            style: const TextStyle(color: Colors.white, fontFamily: 'Outfit',
                                                fontWeight: FontWeight.w700, fontSize: 10)),
                                      ),
                                    ],
                                    if (isMuted) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6B7280),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text('Muted',
                                            style: TextStyle(color: Colors.white, fontFamily: 'Outfit',
                                                fontWeight: FontWeight.w700, fontSize: 10)),
                                      ),
                                    ],
                                  ],
                                ),
                                if (mUsername != null) ...[
                                  Text('@$mUsername',
                                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
                                ],
                              ],
                            ),
                          ),
                          if (canShowActions)
                            GestureDetector(
                              onTap: () => _showMemberActions(m),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.more_vert, size: 24, color: c.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // Search empty state
                if (_memberSearch.isNotEmpty && !_searchLoading && (_searchResults?.isEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No members match "$_memberSearch"',
                          style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
                    ),
                  ),

                // Load more
                if (_hasMoreMembers && _memberSearch.isEmpty)
                  Center(
                    child: _loadingMore
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(color: c.primary),
                          )
                        : TextButton(
                            onPressed: _loadMoreMembers,
                            child: Text('Load more members',
                                style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14)),
                          ),
                  ),
              ],
            ),
          ),

          // ── Leave / Delete ───────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                if (_myRole != 'super_admin')
                  GestureDetector(
                    onTap: _confirmLeave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.exit_to_app, color: Color(0xFFFF9800), size: 20),
                          const SizedBox(width: 8),
                          Text('Leave $_label',
                              style: const TextStyle(color: Color(0xFFFF9800), fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),

                if (_isOwner) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _confirmDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outlined, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Text('Delete $_label',
                              style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load group info', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _load,
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final ThemeColors c;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.label, required this.iconBg,
    required this.iconColor, required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String hint;
  final ThemeColors c;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PermCard({
    required this.icon, required this.iconColor, required this.title,
    required this.hint, required this.c, required this.onTap, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                Text(hint, style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
              ]),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, size: 24, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors c;
  final Color? color;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon, required this.label, required this.c, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final col = color ?? c.text;
    return ListTile(
      leading: Icon(icon, color: col),
      title: Text(label, style: TextStyle(color: col, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _PermToggle extends StatelessWidget {
  final ThemeColors c;
  final String title;
  final String hint;
  final String permKey;
  final Map<String, bool> perms;
  final StateSetter setSt;

  const _PermToggle({
    required this.c, required this.title, required this.hint,
    required this.permKey, required this.perms, required this.setSt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
              Text(hint, style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12, height: 1.4)),
            ]),
          ),
          Switch(
            value: perms[permKey] ?? false,
            onChanged: (v) => setSt(() => perms[permKey] = v),
            activeColor: c.primary,
          ),
        ],
      ),
    );
  }
}
