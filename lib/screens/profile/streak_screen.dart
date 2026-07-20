import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _dayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

String _toDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String get _today => _toDate(DateTime.now());
String get _tomorrow => _toDate(DateTime.now().add(const Duration(days: 1)));

List<List<Map<String, dynamic>?>> _buildGrid(int year, int month) {
  final firstDay = DateTime(year, month, 1).weekday % 7;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final grid = <List<Map<String, dynamic>?>>[];
  var week = List<Map<String, dynamic>?>.filled(firstDay, null, growable: true);
  for (int d = 1; d <= daysInMonth; d++) {
    final ds = '${year.toString()}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    week.add({'day': d, 'date': ds});
    if (week.length == 7) { grid.add(List.from(week)); week = []; }
  }
  if (week.isNotEmpty) {
    while (week.length < 7) week.add(null);
    grid.add(List.from(week));
  }
  return grid;
}

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get bestBannerBg => dark ? const Color(0xFF1C1000) : const Color(0xFFFFF8E1);
  Color get bestBannerBorder => dark ? const Color(0xFF3A2200) : const Color(0xFFFFE082);
  Color get bestBannerText => dark ? const Color(0xFFFFB300) : const Color(0xFFE65100);
}

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});
  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _calYear = DateTime.now().year;
  int _calMonth = DateTime.now().month;

  Map<String, dynamic>? _streakData;
  List<Map<String, dynamic>> _calData = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _friendsLb = [];
  String? _currentUserId;

  bool _loadingStreak = true;
  bool _loadingCal = true;
  bool _loadingLb = false;
  bool _loadingFriendsLb = false;

  Map<String, dynamic>? _alertConfig;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _onTabChanged(_tabCtrl.index); });
    SharedPreferences.getInstance().then((p) { if (mounted) setState(() => _currentUserId = p.getString('uid')); });
    _fetchStreak();
    _fetchCal(_calYear, _calMonth);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _onTabChanged(int i) {
    if (i == 2 && _leaderboard.isEmpty) _fetchLb();
    if (i == 1 && _friendsLb.isEmpty) _fetchFriendsLb();
  }

  Future<void> _fetchStreak() async {
    setState(() => _loadingStreak = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.get('/v1/streaks/$uid');
      if (mounted && res.data['success'] == true) setState(() => _streakData = Map<String, dynamic>.from(res.data['data'] as Map));
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingStreak = false); }
  }

  Future<void> _fetchCal(int year, int month) async {
    setState(() => _loadingCal = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.get('/v1/streaks/$uid/calendar?year=$year&month=$month');
      if (mounted && res.data['success'] == true) setState(() => _calData = List<Map<String, dynamic>>.from((res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingCal = false); }
  }

  Future<void> _fetchLb() async {
    setState(() => _loadingLb = true);
    try {
      final res = await dioClient.get('/v1/streaks/leaderboard');
      if (mounted && res.data['success'] == true) setState(() => _leaderboard = List<Map<String, dynamic>>.from((res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingLb = false); }
  }

  Future<void> _fetchFriendsLb() async {
    setState(() => _loadingFriendsLb = true);
    try {
      final res = await dioClient.get('/v1/streaks/friends-leaderboard');
      if (mounted && res.data['success'] == true) setState(() => _friendsLb = List<Map<String, dynamic>>.from((res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingFriendsLb = false); }
  }

  Future<void> _applyFreeze(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.post('/v1/streaks/$uid/freeze', data: {'date': dateStr});
      if (res.data['success'] == true) {
        await Future.wait([_fetchStreak(), _fetchCal(_calYear, _calMonth)]);
        if (mounted) setState(() => _alertConfig = {'title': 'Streak Frozen!', 'message': res.data['data']?['message'] ?? 'Your streak is protected for this day.'});
      }
    } catch (_) { if (mounted) setState(() => _alertConfig = {'title': 'Error', 'message': 'Failed to apply freeze. Please try again.'}); }
  }

  void _handleDayPress(String dateStr) {
    final today = _today;
    final tomorrow = _tomorrow;
    if (dateStr != today && dateStr != tomorrow) return;
    final frozen = <String>{for (final d in _calData) if (d['frozen'] == true) d['date'].toString()};
    final fi = _streakData?['freezeInfo'] as Map?;
    if (frozen.contains(dateStr)) { setState(() => _alertConfig = {'title': 'Already Frozen', 'message': 'This day is already protected.'}); return; }
    if ((fi?['freezesLeft'] ?? 0) <= 0) { setState(() => _alertConfig = {'title': 'No Freezes Left', 'message': "You've used both streak freezes for this week."}); return; }
    // Show freeze info dialog instead of ad (Flutter doesn't have ads yet)
    setState(() => _alertConfig = {'title': 'Freeze Streak', 'message': 'Tap OK to protect your streak for this day using a freeze.', 'onOk': () { setState(() => _alertConfig = null); _applyFreeze(dateStr); }});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final currentStreak = (_streakData?['currentStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (_streakData?['longestStreak'] as num?)?.toInt() ?? 0;
    final fi = _streakData?['freezeInfo'] as Map? ?? {'weeklyUsed': 0, 'weeklyLimit': 2, 'freezesLeft': 2};
    final freezesLeft = (fi['freezesLeft'] as num?)?.toInt() ?? 2;
    final weeklyLimit = (fi['weeklyLimit'] as num?)?.toInt() ?? 2;
    final qualified = <String>{for (final d in _calData) if (d['qualified'] == true) d['date'].toString()};
    final frozen = <String>{for (final d in _calData) if (d['frozen'] == true) d['date'].toString()};
    final isTodayFrozen = frozen.contains(_today);

    final gradientColors = isTodayFrozen ? [const Color(0xFF0288D1), const Color(0xFF29B6F6), const Color(0xFF4FC3F7)] : [const Color(0xFFF57C00), const Color(0xFFFF9800), const Color(0xFFFFB300)];

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        Column(children: [
          // Gradient header
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: SafeArea(bottom: false, child: Column(children: [
              // Nav row
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Row(children: [
                GestureDetector(onTap: () => context.pop(), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.close, size: 22, color: Colors.white))),
                const Expanded(child: Text('Streak', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white, letterSpacing: 0.3))),
                const SizedBox(width: 38),
              ])),
              // Tab bar
              TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.8),
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,

                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'PERSONAL'), Tab(text: 'FRIENDS'), Tab(text: 'GLOBAL')],
              ),
              // Hero row
              Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 0), child: Row(children: [
                Expanded(child: _loadingStreak
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$currentStreak', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 72, color: Colors.white, height: 1.1)),
                        const Text('day streak!', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('❄️', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text('$freezesLeft/$weeklyLimit freezes left', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                          ]),
                        ),
                      ])),
                Container(
                  width: 100, height: 110,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: isTodayFrozen ? 0.9 : 0.6), width: 3), color: Colors.white.withValues(alpha: isTodayFrozen ? 0.2 : 0.1)),
                  child: Center(child: Text(isTodayFrozen ? '❄️' : '🔥', style: const TextStyle(fontSize: 52))),
                ),
              ])),
              // Tip card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [
                  Text('🧊', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 10),
                  Expanded(child: Text.rich(TextSpan(text: 'Join an ', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF333333), height: 1.4), children: [
                    TextSpan(text: 'Adda', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF57C00))),
                    TextSpan(text: ' for at least '),
                    TextSpan(text: '5 minutes', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF57C00))),
                    TextSpan(text: ' to keep your streak alive!'),
                  ]))),
                ]),
              ),
            ])),
          ),
          // Tab content
          Expanded(child: TabBarView(controller: _tabCtrl, children: [
            _personalTab(t, qualified, frozen, longestStreak, currentStreak),
            _lbTab(t, _friendsLb, _loadingFriendsLb, '👥', 'No friend streaks yet', 'Follow people who follow you back!'),
            _lbTab(t, _leaderboard, _loadingLb, '🏆', 'No active streaks yet', 'Be the first to join an Adda!'),
          ])),
        ]),
        if (_alertConfig != null) _alertDlg(t),
      ]),
    );
  }

  Widget _personalTab(_T t, Set<String> qualified, Set<String> frozen, int longestStreak, int currentStreak) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(children: [
      if (longestStreak > 0) Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: t.bestBannerBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.bestBannerBorder)),
        child: Row(children: [
          const Text('🏅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text.rich(TextSpan(text: 'Your longest streak: ', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.bestBannerText), children: [TextSpan(text: '$longestStreak day${longestStreak != 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700))])),
        ]),
      ),
      // Calendar section
      Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), child: Row(children: [
        Expanded(child: Text('Streak Calendar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text))),
        const Text('❄️', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 3),
        Text('Tap today/tomorrow', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
      ])),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
        child: Column(children: [
          // Legend
          Row(children: [
            Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF57C00), shape: BoxShape.circle)), const SizedBox(width: 5), Text('Qualified', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary))]),
            const SizedBox(width: 16),
            Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF29B6F6), shape: BoxShape.circle)), const SizedBox(width: 5), Text('Frozen', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary))]),
          ]),
          const SizedBox(height: 8),
          // Month nav
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () { setState(() { if (_calMonth == 1) { _calYear--; _calMonth = 12; } else _calMonth--; }); _fetchCal(_calYear, _calMonth); }, child: Icon(Icons.chevron_left, size: 22, color: t.text)),
            Text('${_monthNames[_calMonth - 1]} $_calYear', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: t.text)),
            GestureDetector(onTap: () { setState(() { if (_calMonth == 12) { _calYear++; _calMonth = 1; } else _calMonth++; }); _fetchCal(_calYear, _calMonth); }, child: Icon(Icons.chevron_right, size: 22, color: t.text)),
          ]),
          const SizedBox(height: 10),
          Row(children: [for (final d in _dayLabels) Expanded(child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: t.textTertiary)))]),
          const SizedBox(height: 4),
          if (_loadingCal) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: t.primary))
          else for (final week in _buildGrid(_calYear, _calMonth)) Row(children: week.map((cell) {
            if (cell == null) return const Expanded(child: SizedBox(height: 38));
            final ds = cell['date'] as String;
            final today = _today;
            final tomorrow = _tomorrow;
            final isToday = ds == today;
            final isTomorrow = ds == tomorrow;
            final isQ = qualified.contains(ds);
            final isF = frozen.contains(ds) && !isQ;
            final isFreezable = (isToday || isTomorrow) && !isQ && !isF;
            return Expanded(child: GestureDetector(
              onTap: (isToday || isTomorrow) ? () => _handleDayPress(ds) : null,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isQ ? const Color(0xFFF57C00) : isF ? const Color(0xFF29B6F6) : Colors.transparent,
                    border: isToday && !isQ && !isF ? Border.all(color: const Color(0xFFF57C00), width: 2) : isTomorrow && !isQ && !isF ? Border.all(color: const Color(0xFF29B6F6), width: 2) : null,
                  ),
                  child: Center(child: isF ? const Text('❄️', style: TextStyle(fontSize: 16)) : Text('${cell['day']}', style: TextStyle(fontFamily: 'Outfit', fontWeight: isQ ? FontWeight.w700 : FontWeight.w400, fontSize: 14, color: isQ ? Colors.white : isToday && !isF ? const Color(0xFFF57C00) : isTomorrow && !isF ? const Color(0xFF29B6F6) : t.text))),
                ),
                if (isFreezable) Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 1), decoration: const BoxDecoration(color: Color(0xFF29B6F6), shape: BoxShape.circle)),
              ])),
            ));
          }).toList()),
        ]),
      ),
      // Goals
      Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), child: Text('Streak Goal', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text))),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
        clipBehavior: Clip.hardEdge,
        child: Column(children: [
          for (final goal in [
            (7, '1 Week', '🥉'), (30, '1 Month', '🥈'), (100, '100 Days', '🥇'), (365, '1 Year', '🏆'),
          ]) Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(border: Border(bottom: goal.$1 != 365 ? BorderSide(color: t.border, width: 0.5) : BorderSide.none)),
            child: Row(children: [
              Text(goal.$3, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${goal.$2} Streak', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: t.text)),
                Text('${goal.$1} days', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
              ])),
              if (currentStreak >= goal.$1)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0x2034C759), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.check_circle, size: 16, color: Color(0xFF34C759)), SizedBox(width: 4), Text('Active', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF34C759)))]))
              else if (longestStreak >= goal.$1)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0x20F57C00), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.verified, size: 16, color: Color(0xFFF57C00)), SizedBox(width: 4), Text('Achieved', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFFF57C00)))]))
              else
                Text('${goal.$1 - currentStreak} days left', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
            ]),
          ),
        ]),
      ),
    ]),
  );

  Widget _lbTab(_T t, List<Map<String, dynamic>> data, bool loading, String emoji, String emptyTitle, String emptySub) {
    if (loading) return Center(child: CircularProgressIndicator(color: const Color(0xFFF57C00)));
    if (data.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 8),
      Text(emptyTitle, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: t.text)),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(emptySub, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary, height: 1.4))),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: data.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(emoji == '👥' ? 'Friends Streaks' : 'Global Streaks', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: t.text)));
        final item = data[i - 1];
        final isMe = item['userId'].toString() == _currentUserId;
        final isFirst = item['rank'] == 1;
        final name = item['name']?.toString() ?? item['username']?.toString() ?? 'User';
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFFFF3E0) : t.surface,
            border: Border(bottom: i < data.length ? BorderSide(color: t.border, width: 0.5) : BorderSide.none),
          ),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              ClipOval(child: Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0x20F57C00), border: isFirst ? Border.all(color: const Color(0xFFFFD700), width: 2.5) : null, shape: BoxShape.circle), child: Center(child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFFF57C00)))))),
              if (isFirst) const Positioned(top: -13, left: 11, child: Text('👑', style: TextStyle(fontSize: 16))),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15, color: t.text))),
                if (isMe) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0x20F57C00), borderRadius: BorderRadius.circular(6)), child: const Text('You', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFFF57C00))))],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Text('🔥', style: TextStyle(fontSize: isFirst ? 18 : 16)),
                const SizedBox(width: 2),
                Text('${item['currentStreak'] ?? 0}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13, color: isFirst ? const Color(0xFFE65100) : t.textTertiary)),
                Text(' days', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Lv.${item['currentLevel'] ?? 1}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFF57C00))),
              Text(item['levelTitle']?.toString() ?? 'Newcomer', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.textTertiary)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _alertDlg(_T t) => GestureDetector(
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
          TextButton(
            onPressed: _alertConfig!['onOk'] != null ? (_alertConfig!['onOk'] as VoidCallback) : () => setState(() => _alertConfig = null),
            child: Text('OK', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: t.primary)),
          ),
        ]),
      ]),
    )))),
  );
}
