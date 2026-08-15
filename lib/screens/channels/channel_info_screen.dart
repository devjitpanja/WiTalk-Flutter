import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../cache/witalk_image_cache.dart';
import '../../theme/theme_colors.dart';

extension _CtxX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

const double _kHeroHeight = 230;
const double _kHeaderH = 52;
const double _kFadeThreshold = _kHeroHeight - _kHeaderH * 2;

class ChannelInfoScreen extends StatefulWidget {
  final String channelId;
  const ChannelInfoScreen({super.key, required this.channelId});

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _scrollCtrl = ScrollController();

  Map<String, dynamic>? _channel;
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  bool _muted = false;

  List<Map<String, dynamic>> _mediaItems = [];
  bool _mediaLoading = false;
  bool _mediaLoaded = false;

  List<Map<String, dynamic>> _linkItems = [];
  bool _linksLoading = false;
  bool _linksLoaded = false;

  String _activeTab = 'media';
  double _scrollOffset = 0;

  bool get _isAdmin {
    final role = _channel?['my_role']?.toString();
    return role == 'owner' || role == 'admin';
  }

  bool get _isOwner => _channel?['my_role']?.toString() == 'owner';

  String? get _shareLink {
    if (_channel == null) return null;
    final type = _channel!['channel_type']?.toString();
    final username = _channel!['username']?.toString();
    final inviteCode = _channel!['invite_code']?.toString();
    if (type == 'public' && username != null && username.isNotEmpty) {
      return 'https://witalk.in/$username';
    }
    if (type == 'private' && inviteCode != null && inviteCode.isNotEmpty) {
      return 'https://witalk.in/invite/$inviteCode';
    }
    return null;
  }

  List<Map<String, dynamic>> get _groupedLinks {
    final groups = <Map<String, dynamic>>[];
    final map = <String, Map<String, dynamic>>{};
    for (final item in _linkItems) {
      final raw = item['sent_at'] ?? item['created_at'] ?? '';
      DateTime? d;
      try { d = DateTime.parse(raw.toString()).toLocal(); } catch (_) {}
      d ??= DateTime.now();
      final key = '${d.year}-${d.month}';
      const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
      final label = months[d.month - 1];
      if (!map.containsKey(key)) {
        final g = {'label': label, 'items': <Map<String, dynamic>>[]};
        map[key] = g;
        groups.add(g);
      }
      (map[key]!['items'] as List).add(item);
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
    });
    _fetchChannelInfo();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchChannelInfo() async {
    await _storage.read(key: 'uid');
    try {
      final results = await Future.wait([
        ChannelApi.getById(widget.channelId),
        ChannelApi.getAdmins(widget.channelId),
      ]);
      final ch = results[0].data?['channel'] as Map<String, dynamic>?;
      final adminsList = List<Map<String, dynamic>>.from(results[1].data?['admins'] ?? []);
      if (ch != null && mounted) {
        setState(() {
          _channel = ch;
          _admins = adminsList;
          _muted = ch['is_muted'] == 1 || ch['is_muted'] == true;
          _loading = false;
        });
        _fetchMedia();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMedia() async {
    if (_mediaLoading || _mediaLoaded) return;
    if (mounted) setState(() => _mediaLoading = true);
    try {
      final res = await ChannelApi.getMedia(widget.channelId);
      final list = List<Map<String, dynamic>>.from(res.data?['media'] ?? []);
      if (mounted) setState(() { _mediaItems = list; _mediaLoaded = true; });
    } catch (_) {}
    if (mounted) setState(() => _mediaLoading = false);
  }

  Future<void> _fetchLinks() async {
    if (_linksLoading || _linksLoaded) return;
    if (mounted) setState(() => _linksLoading = true);
    try {
      final res = await ChannelApi.getLinks(widget.channelId);
      final list = List<Map<String, dynamic>>.from(res.data?['links'] ?? []);
      if (mounted) setState(() { _linkItems = list; _linksLoaded = true; });
    } catch (_) {}
    if (mounted) setState(() => _linksLoading = false);
  }

  Future<void> _toggleMute() async {
    try {
      if (_muted) {
        await ChannelApi.unmute(widget.channelId);
      } else {
        await ChannelApi.mute(widget.channelId);
      }
      if (mounted) setState(() => _muted = !_muted);
    } catch (_) {
      _snack('Could not update notification settings', error: true);
    }
  }

  void _copyShareLink() {
    if (_shareLink == null) return;
    Clipboard.setData(ClipboardData(text: _shareLink!));
    _snack('Link copied to clipboard', success: true);
  }

  Future<void> _confirmLeave() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Leave Channel', style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text('You will no longer receive messages from this channel.',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Leave', style: TextStyle(color: c.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChannelApi.unsubscribe(widget.channelId);
      if (mounted) context.go('/channels');
    } catch (_) {
      _snack('Could not leave channel', error: true);
    }
  }

  Future<void> _confirmRevokeLink() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Revoke Invite Link', style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text('The current link will stop working immediately. A new link will be generated.',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Revoke & Regenerate', style: TextStyle(color: c.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ChannelApi.revokeLink(widget.channelId);
      final newCode = res.data?['invite_code'] as String?;
      if (newCode != null && mounted) {
        setState(() => _channel = {..._channel!, 'invite_code': newCode});
      }
    } catch (_) {
      _snack('Could not revoke link', error: true);
    }
  }

  void _snack(String t, {bool error = false, bool success = false}) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t, style: const TextStyle(color: Color(0xFFFFFFFF))),
      backgroundColor: error ? c.danger : success ? c.success : c.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 2500),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;

    if (_loading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: c.background,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: c.background,
          body: Center(child: CircularProgressIndicator(color: c.primary)),
        ),
      );
    }

    final name = _channel?['name']?.toString() ?? 'Channel';
    final iconUrl = _channel?['icon']?.toString();
    final isVerified = _channel?['is_verified'] == 1 || _channel?['is_verified'] == true;
    final subCount = (_channel?['subscriber_count'] as num?)?.toInt() ?? 0;
    final username = _channel?['username']?.toString();
    final desc = _channel?['description']?.toString();
    final channelType = _channel?['channel_type']?.toString();
    final isBanned = _channel?['is_banned_from_channel'] == true;

    // Header fade based on scroll
    final headerOpacity = (_scrollOffset / _kFadeThreshold).clamp(0.0, 1.0);
    final titleOpacity = ((_scrollOffset - (_kFadeThreshold - 20)) / 50).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: c.background,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(children: [
          // ── Scroll body ──
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(children: [
              _buildHero(c, name, iconUrl, isVerified, subCount, username),
              if (isBanned) _buildBannedBody(c) else ...[
                _buildActionRow(c),
                if (_shareLink != null || (desc != null && desc.isNotEmpty))
                  _buildInfoSection(c, desc, channelType),
                if (_isAdmin) _buildAdminPanel(c, subCount),
                if (_isAdmin && !_isOwner) _buildLeaveSection(c),
                if (!_isAdmin) _buildReportSection(c),
                _buildTabBar(c),
                _buildTabContent(c),
                const SizedBox(height: 48),
              ],
            ]),
          ),

          // ── Floating header ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Stack(children: [
                // Header bg fades in
                Opacity(
                  opacity: headerOpacity,
                  child: Container(
                    height: _kHeaderH,
                    color: c.background,
                  ),
                ),
                // Header border
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Opacity(
                    opacity: headerOpacity,
                    child: Container(height: 0.5, color: c.border),
                  ),
                ),
                SizedBox(
                  height: _kHeaderH,
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40, height: 40,
                        margin: const EdgeInsets.only(left: 8),
                        alignment: Alignment.center,
                        child: Icon(Icons.arrow_back, size: 24, color: c.text),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: Text(name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────────
  Widget _buildHero(ThemeColors c, String name, String? iconUrl, bool isVerified,
      int subCount, String? username) {
    final init = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final subLabel = '${subCount.toString()} members${username != null && username.isNotEmpty ? ' · @$username' : ''}';
    final roleStr = _isOwner ? 'Owner' : _isAdmin ? 'Admin' : null;

    return SizedBox(
      height: _kHeroHeight,
      child: Stack(fit: StackFit.expand, children: [
        // Base bg
        Container(color: c.cardBackground),
        // Faint hero bg image
        if (iconUrl != null && iconUrl.isNotEmpty)
          Opacity(
            opacity: 0.09,
            child: CachedNetworkImage(
              cacheManager: WiTalkImageCache(),
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        // Gradient overlay
        Positioned(
          top: _kHeroHeight * 0.4,
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, c.background],
              ),
            ),
          ),
        ),
        // Content
        Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          // Avatar with ring
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.primary, width: 2.5),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? CachedNetworkImage(
                      cacheManager: WiTalkImageCache(),
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarPlaceholder(c, init))
                  : _avatarPlaceholder(c, init),
            ),
          ),
          const SizedBox(height: 12),
          // Name row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text))),
            if (isVerified) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0751df)),
            ],
          ]),
          const SizedBox(height: 4),
          Text(subLabel, style: TextStyle(fontSize: 13, color: c.textTertiary)),
          if (roleStr != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(roleStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)),
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ]),
    );
  }

  Widget _avatarPlaceholder(ThemeColors c, String init) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.primaryButton, c.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Text(init, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
    );
  }

  // ── Action row ────────────────────────────────────────────────────────────────
  Widget _buildActionRow(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        // Message button
        Expanded(child: _actionBtn(
          c, Icons.chat_bubble_outline_rounded, 'Message', c.primary,
          () => context.push('/channel/${widget.channelId}', extra: {'channel': _channel}),
        )),
        const SizedBox(width: 10),
        // Mute/Unmute
        Expanded(child: _actionBtn(
          c, _muted ? Icons.notifications_rounded : Icons.notifications_off_outlined,
          _muted ? 'Unmute' : 'Mute', c.text, _toggleMute,
        )),
        const SizedBox(width: 10),
        // Edit (admin) or Leave (member)
        if (_isAdmin)
          Expanded(child: _actionBtn(
            c, Icons.tune_rounded, 'Edit', c.primary,
            () => context.push('/edit-channel/${widget.channelId}', extra: {'channel': _channel}),
          ))
        else
          Expanded(child: _actionBtn(
            c, Icons.exit_to_app_rounded, 'Leave', c.danger, _confirmLeave,
          )),
      ]),
    );
  }

  Widget _actionBtn(ThemeColors c, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────────────────────
  Widget _buildInfoSection(ThemeColors c, String? desc, String? channelType) {
    final link = _shareLink;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        if (link != null) ...[
          _infoRow(
            c,
            iconBg: c.primary.withValues(alpha: 0.13),
            icon: Icons.link_rounded,
            iconColor: c.primary,
            label: channelType == 'public' ? 'Channel link' : 'Invite link',
            value: link,
            valueColor: c.primary,
            trailing: Icon(Icons.content_copy_rounded, size: 17, color: c.textTertiary),
            onTap: _copyShareLink,
          ),
          if (_isOwner && channelType == 'private') ...[
            Container(height: 0.5, margin: const EdgeInsets.only(left: 56), color: c.border),
            _infoRow(
              c,
              iconBg: c.danger.withValues(alpha: 0.13),
              icon: Icons.link_off_rounded,
              iconColor: c.danger,
              label: null,
              value: 'Revoke & generate new link',
              valueColor: c.danger,
              onTap: _confirmRevokeLink,
            ),
          ],
        ],
        if (desc != null && desc.isNotEmpty) ...[
          if (link != null)
            Container(height: 0.5, margin: const EdgeInsets.only(left: 56), color: c.border),
          _infoRow(
            c,
            iconBg: c.primaryButton.withValues(alpha: 0.13),
            icon: Icons.info_outline_rounded,
            iconColor: c.primaryButton,
            label: 'About',
            value: desc,
            valueColor: c.text,
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(ThemeColors c, {
    required Color iconBg, required IconData icon, required Color iconColor,
    required String? label, required String value, required Color valueColor,
    Widget? trailing, VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            if (label != null)
              Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
            Text(value, style: TextStyle(fontSize: 14, color: valueColor, height: 1.45),
              maxLines: label == null ? 1 : null, overflow: label == null ? TextOverflow.ellipsis : null),
          ])),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  // ── Admin panel ───────────────────────────────────────────────────────────────
  Widget _buildAdminPanel(ThemeColors c, int subCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: c.cardBackground, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Management', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.6, color: c.textTertiary))),
        ),
        _mgmtRow(c,
          iconBg: c.success.withValues(alpha: 0.13),
          icon: Icons.admin_panel_settings_rounded,
          iconColor: c.success,
          label: 'Administrators',
          count: '${_admins.length}',
          onTap: () => context.push('/channel-admins/${widget.channelId}',
              extra: {'isOwner': _isOwner}),
        ),
        Container(height: 0.5, margin: const EdgeInsets.only(left: 58), color: c.border),
        _mgmtRow(c,
          iconBg: c.primary.withValues(alpha: 0.13),
          icon: Icons.people_rounded,
          iconColor: c.primary,
          label: 'Subscribers',
          count: subCount.toString(),
          onTap: () => context.push('/channel-subscribers/${widget.channelId}',
              extra: {'subscriberCount': subCount, 'isOwner': _isOwner, 'isAdmin': _isAdmin}),
        ),
        Container(height: 0.5, margin: const EdgeInsets.only(left: 58), color: c.border),
        _mgmtRow(c,
          iconBg: c.danger.withValues(alpha: 0.13),
          icon: Icons.block_rounded,
          iconColor: c.danger,
          label: 'Banned Users',
          onTap: () => context.push('/channel-banned-users/${widget.channelId}'),
        ),
      ]),
    );
  }

  Widget _mgmtRow(ThemeColors c, {
    required Color iconBg, required IconData icon, required Color iconColor,
    required String label, String? count, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c.text))),
          if (count != null) ...[
            Text(count, style: TextStyle(fontSize: 14, color: c.textTertiary)),
            const SizedBox(width: 2),
          ],
          Icon(Icons.chevron_right_rounded, size: 20, color: c.textTertiary),
        ]),
      ),
    );
  }

  // ── Leave section (non-owner admins) ──────────────────────────────────────────
  Widget _buildLeaveSection(ThemeColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: c.cardBackground, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: GestureDetector(
        onTap: _confirmLeave,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.exit_to_app_rounded, size: 18, color: c.danger),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Leave Channel', style: TextStyle(fontSize: 15, color: c.danger))),
          ]),
        ),
      ),
    );
  }

  // ── Report section (non-admins) ───────────────────────────────────────────────
  Widget _buildReportSection(ThemeColors c) {
    const reportColor = Color(0xFFE74C3C);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: c.cardBackground, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: GestureDetector(
        onTap: () => _snack('Report submitted'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: reportColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.flag_rounded, size: 18, color: reportColor),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Report Channel',
                style: TextStyle(fontSize: 15, color: reportColor))),
          ]),
        ),
      ),
    );
  }

  // ── Banned body ───────────────────────────────────────────────────────────────
  Widget _buildBannedBody(ThemeColors c) {
    return SizedBox(
      height: 300,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.block_rounded, size: 56, color: c.danger),
        const SizedBox(height: 12),
        Text('You have been banned',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text('You can no longer access or join this channel.',
              style: TextStyle(fontSize: 14, color: c.textTertiary, height: 1.45),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────────
  Widget _buildTabBar(ThemeColors c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(children: ['media', 'links'].map((tab) {
        final active = _activeTab == tab;
        return Expanded(child: GestureDetector(
          onTap: () {
            setState(() => _activeTab = tab);
            if (tab == 'media' && !_mediaLoaded) _fetchMedia();
            if (tab == 'links' && !_linksLoaded) _fetchLinks();
          },
          child: Stack(alignment: Alignment.bottomCenter, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tab == 'media' ? 'Media' : 'Links',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: active ? c.primary : c.textTertiary)),
            ),
            if (active)
              Container(height: 2, decoration: BoxDecoration(
                color: c.primary, borderRadius: BorderRadius.circular(2))),
          ]),
        ));
      }).toList()),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────────
  Widget _buildTabContent(ThemeColors c) {
    if (_activeTab == 'media') return _buildMediaGrid(c);
    return _buildLinksList(c);
  }

  Widget _buildMediaGrid(ThemeColors c) {
    if (_mediaLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_mediaItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(children: [
          Icon(Icons.photo_library_outlined, size: 44, color: c.border),
          const SizedBox(height: 10),
          Text('No media yet', style: TextStyle(fontSize: 14, color: c.textTertiary)),
        ]),
      );
    }
    final size = (MediaQuery.of(context).size.width - 32 - 4) / 3;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 2, runSpacing: 2, children: _mediaItems.map((item) {
        String? thumbUrl = item['media_url']?.toString();
        if (item['message_type'] == 'image_album') {
          try {
            final md = item['media_data'];
            final parsed = md is String ? jsonDecode(md) : md;
            final imgs = parsed?['images'] as List?;
            if (imgs != null && imgs.isNotEmpty) {
              thumbUrl = (imgs[0] is Map ? imgs[0]['url'] : imgs[0])?.toString() ?? thumbUrl;
            }
          } catch (_) {}
        }
        return GestureDetector(
          onTap: () => context.push('/channel/${widget.channelId}',
              extra: {'channel': _channel, 'focusMessageId': item['id']?.toString()}),
          child: SizedBox(
            width: size, height: size,
            child: Stack(fit: StackFit.expand, children: [
              thumbUrl != null
                  ? CachedNetworkImage(
                      cacheManager: WiTalkImageCache(),
                      imageUrl: thumbUrl, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: c.border))
                  : Container(color: c.border),
              if (item['message_type'] == 'video')
                Container(
                  color: const Color(0x40000000),
                  child: const Icon(Icons.play_circle_filled_rounded, size: 28, color: Color(0xFFFFFFFF))),
              if (item['message_type'] == 'image_album')
                const Positioned(top: 4, right: 4,
                  child: Icon(Icons.collections_rounded, size: 14, color: Color(0xFFFFFFFF))),
            ]),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildLinksList(ThemeColors c) {
    if (_linksLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_linkItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(children: [
          Icon(Icons.link_rounded, size: 44, color: c.border),
          const SizedBox(height: 10),
          Text('No links yet', style: TextStyle(fontSize: 14, color: c.textTertiary)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _groupedLinks.map((group) {
        final items = group['items'] as List<Map<String, dynamic>>;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text((group['label'] as String).toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                letterSpacing: 0.4, color: c.textTertiary)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: c.cardBackground, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.hardEdge,
            child: Column(children: List.generate(items.length, (idx) {
              final item = items[idx];
              Map<String, dynamic>? preview;
              try {
                final raw = item['link_preview'];
                preview = raw is String ? Map<String, dynamic>.from(jsonDecode(raw)) : (raw is Map ? Map<String, dynamic>.from(raw) : null);
              } catch (_) {}
              final url = preview?['url']?.toString() ?? '';
              final title = preview?['title']?.toString() ?? url;
              final letter = title.isNotEmpty ? title[0].toUpperCase() : 'L';
              return Column(children: [
                if (idx > 0) Container(height: 0.5, margin: const EdgeInsets.only(left: 68), color: c.border),
                GestureDetector(
                  onTap: () => context.push('/channel/${widget.channelId}',
                      extra: {'channel': _channel, 'focusMessageId': item['id']?.toString()}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: Text(letter, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                        const SizedBox(height: 3),
                        Text(url, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.primary)),
                      ])),
                    ]),
                  ),
                ),
              ]);
            })),
          ),
          const SizedBox(height: 4),
        ]);
      }).toList()),
    );
  }
}
