import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}

class BlockedAccountsScreen extends ConsumerStatefulWidget {
  const BlockedAccountsScreen({super.key});
  @override
  ConsumerState<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends ConsumerState<BlockedAccountsScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  String? _unblockingId;
  Map<String, dynamic>? _alertConfig;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.get('/v1/block/list/$uid');
      if (mounted && res.data['success'] == true) {
        setState(() => _blocked = List<Map<String, dynamic>>.from((res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _confirmUnblock(String blockedId, String name) {
    setState(() => _alertConfig = {
      'visible': true,
      'title': 'Unblock User',
      'message': 'Are you sure you want to unblock $name?',
      'onConfirm': () async {
        setState(() => _alertConfig = null);
        await _doUnblock(blockedId, name);
      },
    });
  }

  Future<void> _doUnblock(String blockedId, String name) async {
    setState(() => _unblockingId = blockedId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.post('/v1/block/unblock', data: {'blocker_id': uid, 'blocked_id': blockedId});
      if (res.data['success'] == true && mounted) {
        setState(() => _blocked.removeWhere((u) => u['blocked_id'].toString() == blockedId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name has been unblocked', style: const TextStyle(fontFamily: 'Outfit'))));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to unblock user')));
    } finally { if (mounted) setState(() => _unblockingId = null); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
              Expanded(child: Text('Blocked Accounts', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
              const SizedBox(width: 32),
            ]),
          ),
          Expanded(child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary))
              : _blocked.isEmpty
                  ? _empty(t)
                  : ListView.builder(
                      itemCount: _blocked.length,
                      itemBuilder: (_, i) => _item(_blocked[i], t),
                    )),
        ]),
        if (_alertConfig != null) _alertDialog(t),
      ])),
    );
  }

  Widget _item(Map<String, dynamic> item, _T t) {
    final id = item['blocked_id'].toString();
    final name = item['name']?.toString() ?? item['username']?.toString() ?? 'User';
    final username = item['username']?.toString();
    final pic = item['profile_pic']?.toString();
    final isUnblocking = _unblockingId == id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.push('/user/$id'),
          child: Row(children: [
            ClipOval(child: pic != null && pic.isNotEmpty
                ? CachedNetworkImage(imageUrl: pic, width: 46, height: 46, fit: BoxFit.cover)
                : Container(width: 46, height: 46, color: t.primary, alignment: Alignment.center, child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
              if (username != null && name != username) Text('@$username', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary)),
            ]),
          ]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: isUnblocking ? null : () => _confirmUnblock(id, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: t.primary)),
            child: isUnblocking
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary))
                : Text('Unblock', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.primary)),
          ),
        ),
      ]),
    );
  }

  Widget _empty(_T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.block, size: 56, color: t.textTertiary),
    const SizedBox(height: 18),
    Text('No blocked accounts', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17, color: t.text)),
    const SizedBox(height: 6),
    Text('Users you block will appear here', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary)),
  ]));

  Widget _alertDialog(_T t) => GestureDetector(
    onTap: () => setState(() => _alertConfig = null),
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
          TextButton(onPressed: () => setState(() => _alertConfig = null), child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: t.textTertiary))),
          TextButton(onPressed: _alertConfig!['onConfirm'] as VoidCallback, child: Text('Unblock', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: t.primary))),
        ]),
      ]),
    )))),
  );
}
