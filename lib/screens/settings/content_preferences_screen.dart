import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get infoBg => dark ? const Color(0xFF1a2332) : const Color(0xFFE8F4FD);
  Color get infoBorder => dark ? const Color(0xFF2a3f5f) : const Color(0xFFB3D9F2);
  Color get infoText => dark ? const Color(0xFFB3D9F2) : const Color(0xFF0056B3);
  Color get infoIcon => dark ? const Color(0xFF64B5F6) : const Color(0xFF007AFF);
  Color get skBase => dark ? const Color(0xFF1a1f2e) : const Color(0xFFE1E9EE);
  Color get skHi => dark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);
}

class ContentPreferencesScreen extends ConsumerStatefulWidget {
  const ContentPreferencesScreen({super.key});
  @override
  ConsumerState<ContentPreferencesScreen> createState() => _ContentPreferencesScreenState();
}

class _ContentPreferencesScreenState extends ConsumerState<ContentPreferencesScreen> {
  List<Map<String, dynamic>> _excluded = [];
  bool _loading = true;
  String? _removingId;
  Map<String, dynamic>? _alertConfig;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.get('/v2/excluded-users/$uid');
      if (mounted && res.data['success'] == true) {
        setState(() => _excluded = List<Map<String, dynamic>>.from((res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _onRefresh() async { await _load(); }

  void _confirmRemove(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? user['username']?.toString() ?? 'this user';
    setState(() => _alertConfig = {
      'title': 'Remove Exclusion',
      'message': 'Do you want to start seeing posts from $name again?',
      'onConfirm': () async { setState(() => _alertConfig = null); await _doRemove(user); },
      'onCancel': () => setState(() => _alertConfig = null),
    });
  }

  Future<void> _doRemove(Map<String, dynamic> user) async {
    final excludedId = user['excluded_user_id'].toString();
    setState(() => _removingId = excludedId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.post('/v2/excluded-users/remove', data: {'user_id': uid, 'excluded_user_id': excludedId});
      if (res.data['success'] == true && mounted) {
        setState(() => _excluded.removeWhere((u) => u['excluded_user_id'].toString() == excludedId));
        final name = user['name']?.toString() ?? user['username']?.toString() ?? 'User';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You'll now see posts from $name", style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: const Color(0xFF34C759)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove exclusion'), backgroundColor: Color(0xFFFF453A)));
    } finally { if (mounted) setState(() => _removingId = null); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    if (_loading) return _skeleton(t);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          _header(t),
          Expanded(child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _onRefresh),
              if (_excluded.isEmpty)
                SliverFillRemaining(child: _emptyState(t))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    _infoCard(t),
                    const SizedBox(height: 8),
                    ..._excluded.map((u) => _userCard(u, t)),
                  ])),
                ),
            ],
          )),
        ]),
        if (_alertConfig != null) _alertDialog(t),
      ])),
    );
  }

  Widget _header(_T t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
      Expanded(child: Text('Content Preferences', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
      const SizedBox(width: 40),
    ]),
  );

  Widget _infoCard(_T t) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: t.infoBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.infoBorder)),
    child: Row(children: [
      Icon(Icons.info_outline, size: 20, color: t.infoIcon),
      const SizedBox(width: 10),
      Expanded(child: Text('${_excluded.length} user${_excluded.length != 1 ? 's' : ''} excluded. Their posts won\'t appear in your feed.', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13, color: t.infoText, height: 1.4))),
    ]),
  );

  Widget _userCard(Map<String, dynamic> user, _T t) {
    final id = user['excluded_user_id'].toString();
    final name = user['name']?.toString() ?? 'Unknown User';
    final username = user['username']?.toString() ?? 'unknown';
    final pic = user['profile_pic']?.toString();
    final isRemoving = _removingId == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
      child: Row(children: [
        ClipOval(child: pic != null && pic.isNotEmpty
            ? CachedNetworkImage(imageUrl: pic, width: 50, height: 50, fit: BoxFit.cover)
            : Container(width: 50, height: 50, color: t.primary, alignment: Alignment.center, child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
          Text('@$username', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary)),
        ])),
        GestureDetector(
          onTap: isRemoving ? null : () => _confirmRemove(user),
          child: Opacity(opacity: isRemoving ? 0.5 : 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0x15007AFF), borderRadius: BorderRadius.circular(8)),
            child: isRemoving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007AFF)))
                : const Row(children: [
                    Icon(Icons.visibility, size: 18, color: Color(0xFF007AFF)),
                    SizedBox(width: 6),
                    Text('Show', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF007AFF))),
                  ]),
          )),
        ),
      ]),
    );
  }

  Widget _emptyState(_T t) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 120, height: 120, decoration: BoxDecoration(color: t.primary.withAlpha(0x15), shape: BoxShape.circle), child: Icon(Icons.visibility_off, size: 64, color: t.primary)),
      const SizedBox(height: 24),
      Text('No Excluded Users', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text)),
      const SizedBox(height: 8),
      Text("When you exclude users, they'll appear here.\nYou won't see their posts in your feed.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary, height: 1.5)),
    ]),
  );

  Widget _skeleton(_T t) => Scaffold(
    backgroundColor: t.bg,
    body: SafeArea(child: Column(children: [
      _header(t),
      Expanded(child: Shimmer.fromColors(
        baseColor: t.skBase, highlightColor: t.skHi,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(height: 60, decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) ...[
            Container(margin: const EdgeInsets.only(bottom: 10), height: 80, decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(12))),
          ],
        ]),
      )),
    ])),
  );

  Widget _alertDialog(_T t) => GestureDetector(
    onTap: _alertConfig!['onCancel'] as VoidCallback,
    child: Container(color: Colors.black.withValues(alpha: 0.5), child: Center(child: GestureDetector(onTap: () {}, child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_alertConfig!['title'].toString(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text)),
        const SizedBox(height: 8),
        Text(_alertConfig!['message'].toString(), style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: _alertConfig!['onCancel'] as VoidCallback, child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: t.textTertiary))),
          TextButton(onPressed: _alertConfig!['onConfirm'] as VoidCallback, child: Text('Yes, show posts', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: t.primary))),
        ]),
      ]),
    )))),
  );
}
