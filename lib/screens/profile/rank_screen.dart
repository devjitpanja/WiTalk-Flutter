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
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get accent => const Color(0xFF0751DF);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get podiumBar => dark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.4);
  Color get currentUserBg => dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  Color get currentUserBorder => dark ? accent : primary;
}

String _fmtPoints(num? points) {
  if (points == null || points == 0) return '0';
  if (points >= 1000000) return '${(points / 1000000).toStringAsFixed(1)}M';
  if (points >= 1000) return '${(points / 1000).toStringAsFixed(1)}K';
  return points.toStringAsFixed(0);
}

class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});
  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen> {
  Map<String, dynamic>? _rankData;
  bool _loading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) throw Exception('Not authenticated');
      setState(() => _currentUserId = uid);
      final res = await dioClient.get('/v1/rank/user/$uid');
      final data = res.data['data'] ?? res.data;
      if (data != null) setState(() => _rankData = Map<String, dynamic>.from(data as Map));
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        // Header
        Container(
          decoration: BoxDecoration(color: t.accent, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30))),
          padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top, 0, size.height * 0.04),
          child: Column(children: [
            Padding(padding: EdgeInsets.fromLTRB(size.width * 0.04, 0, size.width * 0.04, size.height * 0.03), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              SizedBox(width: 40, child: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back, color: Colors.white, size: 24))),
              Expanded(child: Text('Leaderboard', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: size.width * 0.055, color: Colors.white))),
              const SizedBox(width: 40),
            ])),
            if (_loading)
              SizedBox(height: size.height * 0.25, child: const Center(child: CircularProgressIndicator(color: Colors.white)))
            else if (_rankData != null && (_rankData!['rank_list'] as List?)?.isNotEmpty == true)
              _podium(t, size, List<Map<String, dynamic>>.from((_rankData!['rank_list'] as List).take(3).map((e) => Map<String, dynamic>.from(e as Map)))),
          ]),
        ),
        // List
        Expanded(child: _loading
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: t.accent), const SizedBox(height: 12), Text('Loading rankings...', style: TextStyle(fontFamily: 'Outfit', color: t.textSecondary))]))
            : _error != null
                ? _errorState(t)
                : _rankData == null || (_rankData!['rank_list'] as List?)?.isEmpty == true
                    ? _emptyState(t)
                    : _list(t, size)),
      ]),
    );
  }

  Widget _podium(_T t, Size size, List<Map<String, dynamic>> top) {
    final order = [1, 0, 2]; // 2nd, 1st, 3rd visually
    final heights = [size.height * 0.12, size.height * 0.15, size.height * 0.10];
    return SizedBox(
      height: size.height * 0.25,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (int vi = 0; vi < order.length; vi++) ...[
          if (vi < top.length && order[vi] < top.length) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: top[order[vi]]['id'].toString() == _currentUserId ? null : () => context.push('/user/${top[order[vi]]['id']}'),
              child: Column(children: [
                ClipOval(child: top[order[vi]]['profile_pic'] != null
                    ? CachedNetworkImage(imageUrl: top[order[vi]]['profile_pic'].toString(), width: size.width * 0.15, height: size.width * 0.15, fit: BoxFit.cover)
                    : Container(width: size.width * 0.15, height: size.width * 0.15, color: Colors.white.withValues(alpha: 0.3), child: Center(child: Text((top[order[vi]]['name'] as String? ?? 'U').substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 22))))),
                const SizedBox(height: 4),
                Text(top[order[vi]]['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: size.width * 0.04, color: Colors.white)),
                const SizedBox(height: 4),
                Container(padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.008), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Text(_fmtPoints(top[order[vi]]['rank_points'] as num?), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: size.width * 0.035, color: t.accent))),
                const SizedBox(height: 5),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: heights[vi],
              decoration: BoxDecoration(color: t.podiumBar, borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
              child: Center(child: Text('#${order[vi] + 1}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white, fontSize: size.width * 0.07))),
            ),
          ])),
          if (vi < 2) const SizedBox(width: 4),
        ],
      ]),
    );
  }

  Widget _list(_T t, Size size) {
    final rankList = List<Map<String, dynamic>>.from((_rankData!['rank_list'] as List).skip(3).map((e) => Map<String, dynamic>.from(e as Map)));
    final myRank = _rankData!['myrank'] != null ? Map<String, dynamic>.from(_rankData!['myrank'] as Map) : null;
    final meInList = rankList.firstWhere((u) => u['id'].toString() == _currentUserId, orElse: () => {});
    final listData = meInList.isNotEmpty
        ? [meInList, ...rankList.where((u) => u['id'].toString() != _currentUserId).toList()]
        : myRank != null
            ? [myRank, ...rankList]
            : rankList;
    if (listData.isEmpty) return Center(child: Text('Only top 3 ranked this period', style: TextStyle(fontFamily: 'Outfit', color: t.textSecondary)));
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(size.width * 0.05, size.height * 0.01, size.width * 0.05, size.height * 0.02 + MediaQuery.of(context).padding.bottom),
      itemCount: listData.length,
      itemBuilder: (_, i) => _listItem(listData[i], t, size),
    );
  }

  Widget _listItem(Map<String, dynamic> item, _T t, Size size) {
    final isMe = item['id'].toString() == _currentUserId;
    final rank = item['rank'];
    final isUnranked = rank == null;
    return GestureDetector(
      onTap: isMe ? null : () => context.push('/user/${item['id']}'),
      child: Container(
        margin: EdgeInsets.only(bottom: size.height * 0.015),
        padding: EdgeInsets.symmetric(vertical: size.height * 0.02, horizontal: size.width * 0.04),
        decoration: BoxDecoration(
          color: isMe ? t.currentUserBg : t.bg,
          borderRadius: BorderRadius.circular(isMe ? 15 : 12),
          border: isMe ? Border.all(color: t.currentUserBorder, width: 2) : null,
        ),
        child: Row(children: [
          Text(isUnranked ? '--' : (rank < 10 ? '0$rank' : '$rank'), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: size.width * 0.045, color: isMe ? t.primary : t.textSecondary)),
          SizedBox(width: size.width * 0.04),
          ClipOval(child: item['profile_pic'] != null
              ? CachedNetworkImage(imageUrl: item['profile_pic'].toString(), width: size.width * 0.125, height: size.width * 0.125, fit: BoxFit.cover)
              : Container(width: size.width * 0.125, height: size.width * 0.125, color: t.surface, child: Center(child: Text((item['name'] as String? ?? 'U').substring(0, 1).toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: t.text, fontSize: 18))))),
          SizedBox(width: size.width * 0.04),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: size.width * 0.04, color: t.text)),
            Text(isUnranked ? 'Unranked - Complete missions to get ranked!' : '${_fmtPoints(item['rank_points'] as num?)} mission points', style: TextStyle(fontFamily: 'Outfit', fontSize: size.width * 0.035, color: t.textSecondary)),
          ])),
          if (isMe) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(12)), child: const Text('You', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white))),
        ]),
      ),
    );
  }

  Widget _emptyState(_T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('No Rankings Yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
    const SizedBox(height: 8),
    Text('Rankings will be available once users start completing missions.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
    const SizedBox(height: 20),
    GestureDetector(onTap: _fetch, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(8)), child: const Text('Refresh', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)))),
  ]));

  Widget _errorState(_T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('Oops! Something went wrong', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFFFF453A))),
    const SizedBox(height: 8),
    Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
    const SizedBox(height: 20),
    GestureDetector(onTap: _fetch, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(8)), child: const Text('Try Again', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)))),
  ]));
}
