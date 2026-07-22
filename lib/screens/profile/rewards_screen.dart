import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get cardBg => dark ? const Color(0xFF1e2330) : const Color(0xFFf5f7fa);
  Color get meBg => dark ? const Color(0xFF1a2640) : const Color(0xFFeff6ff);
  Color get rankBadgeBg => dark ? const Color(0xFF2a2f3e) : const Color(0xFFE5E5EA);
  Color get footerBg => dark ? const Color(0xFF1e2330) : const Color(0xFFF5F7FA);
  Color get mprBannerBg => dark ? const Color(0xFF2a1f10) : const Color(0xFFfff7ed);
  Color get mprBannerBorder => dark ? const Color(0x3892400E) : const Color(0xFFfed7aa);
}

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});
  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _myRank;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!_refreshing) setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) throw Exception('Not authenticated');
      final res = await dioClient.get('/v1/rewards/leaderboard', queryParameters: {'userId': uid});
      final raw = res.data;
      Map<String, dynamic>? data;
      if (raw['data'] != null) {
        data = Map<String, dynamic>.from(raw['data'] as Map);
      } else {
        data = Map<String, dynamic>.from(raw as Map);
      }
      if (mounted) setState(() {
        _config = data?['config'] != null ? Map<String, dynamic>.from(data!['config'] as Map) : null;
        _leaderboard = data?['rank_list'] != null ? (data!['rank_list'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
        _myRank = data?['myrank'] != null ? Map<String, dynamic>.from(data!['myrank'] as Map) : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load rewards');
    } finally {
      if (mounted) setState(() { _loading = false; _refreshing = false; });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final now = DateTime.now();
    final monthName = _monthName(now.month);
    final year = now.year;

    final isPoolEmpty = _config == null || (_config!['total_pool'] == null) || (double.tryParse(_config!['total_pool'].toString()) ?? 0) == 0;
    final minPoints = ((_config?['min_points_required'] as num?) ?? 0).toDouble();
    final myPoints = double.tryParse((_myRank?['mission_points'] ?? _myRank?['rank_points'] ?? 0).toString()) ?? 0;
    final pointsNeeded = (minPoints - myPoints).clamp(0, double.infinity);
    final progressPct = minPoints > 0 ? (myPoints / minPoints).clamp(0.0, 1.0) : 1.0;
    final distLen = (_config?['distribution'] is Map) ? (_config!['distribution'] as Map).length : 4;
    final isEligible = myPoints >= minPoints || minPoints == 0;
    final myRankNum = (_myRank?['rank'] as num?)?.toInt();
    final isInRewardZone = isEligible && myRankNum != null && myRankNum <= distLen;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          height: 56,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 56, alignment: Alignment.center, child: Icon(Icons.arrow_back, size: 24, color: t.text))),
            Expanded(child: Text('Contributor Rewards', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
            const SizedBox(width: 40),
          ]),
        ),

        Expanded(child: _loading && !_refreshing
            ? Center(child: CircularProgressIndicator(color: t.primary))
            : _error != null
                ? _errorState(t)
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        sliver: SliverToBoxAdapter(
                          child: isPoolEmpty
                              ? _emptyPoolBody(t, monthName, year)
                              : _fullBody(t, isDark, monthName, year, minPoints, myPoints, pointsNeeded.toDouble(), progressPct, distLen, isEligible, myRankNum, isInRewardZone),
                        ),
                      ),
                    ],
                  )),

        // Sticky bottom button
        if (!_loading && _error == null) Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border)), color: t.bg),
          child: GestureDetector(
            onTap: () => context.push('/rank'),
            child: Container(
              height: 52,
              decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Show Full Rankings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 24, color: Colors.white),
              ]),
            ),
          ),
        ),
      ])),
    );
  }

  Widget _errorState(_T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.error_outline, size: 48, color: t.textTertiary),
    const SizedBox(height: 16),
    Text(_error!, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: t.textTertiary), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    GestureDetector(onTap: _fetch, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(8)), child: const Text('Retry', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)))),
  ]));

  Widget _emptyPoolBody(_T t, String monthName, int year) => Column(children: [
    _banner(t, monthName, year, isPoolEmpty: true),
    const SizedBox(height: 24),
    Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(Icons.schedule, size: 32, color: t.primary),
        const SizedBox(height: 12),
        Text('Prize Pool Coming Soon', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text("This month's reward pool hasn't been announced yet. Stay active, earn points, and climb the leaderboard — your rank will determine your share once the rewards go live!", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary, height: 1.6), textAlign: TextAlign.center),
      ]),
    ),
    const SizedBox(height: 24),
    _footerInfo(t, "Rewards are finalized and distributed at the start of the following month. Stay active and climb the leaderboard!"),
  ]);

  Widget _fullBody(_T t, bool isDark, String monthName, int year, double minPoints, double myPoints, double pointsNeeded, double progressPct, int distLen, bool isEligible, int? myRankNum, bool isInRewardZone) {
    String? motivText;
    IconData? motivIcon;
    bool isWarn = false;
    if (pointsNeeded > 0) {
      motivText = '${_fmtNum(pointsNeeded.toInt())} more pts to unlock rewards!';
      motivIcon = Icons.bolt;
      isWarn = true;
    } else if (!isInRewardZone && myRankNum != null) {
      motivText = "You're Rank #$myRankNum — reach Top $distLen to earn!";
      motivIcon = Icons.trending_up;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _banner(t, monthName, year, motivText: motivText, motivIcon: motivIcon, isWarn: isWarn, progressPct: progressPct, showProgress: minPoints > 0 && pointsNeeded > 0, expectedReward: _myRank?['expected_reward']),
      const SizedBox(height: 24),

      // Distribution section
      _sectionHeader(Icons.pie_chart, 'Pool Distribution', t),
      if ((minPoints) > 0) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.mprBannerBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mprBannerBorder)),
          child: Row(children: [
            const Icon(Icons.stars, size: 18, color: Color(0xFFf97316)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Minimum Points Required', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? const Color(0xFFfb923c) : const Color(0xFFc2410c))),
              Text('${_fmtNum(minPoints.toInt())} pts to qualify for rewards', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? const Color(0xFFfdba74) : const Color(0xFFea580c))),
            ])),
          ]),
        ),
      ],
      _distributionGrid(t, isDark, myRankNum),
      const SizedBox(height: 24),

      // Leaderboard section
      _sectionHeader(Icons.leaderboard, 'Current Leaders', t),
      _leaderboardCard(t, isDark, minPoints, myPoints),
      const SizedBox(height: 24),
      _footerInfo(t, 'Rewards reflect current rankings and may change until the month ends. Payouts are finalized at the start of the next month.'),
    ]);
  }

  Widget _banner(_T t, String monthName, int year, {bool isPoolEmpty = false, String? motivText, IconData? motivIcon, bool isWarn = false, double progressPct = 0, bool showProgress = false, dynamic expectedReward}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.primary, _darkenPrimary(t.primary)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x330000FF), offset: Offset(0, 4), blurRadius: 8)],
      ),
      child: Column(children: [
        Text('$monthName $year Prize Pool', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xE6FFFFFF), letterSpacing: 1)),
        const SizedBox(height: 8),
        if (isPoolEmpty) ...[
          const Icon(Icons.emoji_events, size: 56, color: Color(0xE6FFFFFF)),
          const SizedBox(height: 12),
          const Text('Rewards Not Released Yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white), textAlign: TextAlign.center),
        ] else ...[
          Text('₹${_config?['total_pool'] ?? '0.00'}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 48, color: Colors.white, height: 1.1)),
          const SizedBox(height: 16),
          if (showProgress) Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progressPct, backgroundColor: Colors.white.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Color(0xFFfdba74)), minHeight: 5)),
          ),
          if (motivText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: isWarn ? const Color(0x40f97316) : Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(motivIcon ?? Icons.bolt, size: 16, color: isWarn ? const Color(0xFFfdba74) : Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Flexible(child: Text(motivText, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: isWarn ? const Color(0xFFfdba74) : Colors.white), textAlign: TextAlign.center)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_balance_wallet, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text('Expected Reward: ₹${expectedReward ?? '0.00'}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _sectionHeader(IconData icon, String title, _T t) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Icon(icon, size: 20, color: t.text),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
    ]),
  );

  Widget _distributionGrid(_T t, bool isDark, int? myRankNum) {
    final dist = _config?['distribution'];
    if (dist == null || dist is! Map || dist.isEmpty) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('No distribution set for this month.', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary)));
    }
    final entries = (dist as Map).entries.toList();
    return Wrap(spacing: 12, runSpacing: 12, children: entries.map((e) {
      final rank = e.key.toString();
      final pct = e.value.toString();
      final total = double.tryParse(_config!['total_pool'].toString()) ?? 0;
      final pctVal = double.tryParse(pct) ?? 0;
      final amount = (total * pctVal / 100).toStringAsFixed(0);
      final isMe = myRankNum != null && int.tryParse(rank) == myRankNum;
      return Container(
        width: (MediaQuery.of(context).size.width - 32 - 12) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isMe ? Border.all(color: t.primary, width: 2) : null,
        ),
        child: Stack(children: [
          if (isMe) Positioned(top: 0, right: 0, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(6)),
            child: const Text('You', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
          )),
          Column(children: [
            Text('Rank $rank', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13, color: t.textSecondary)),
            const SizedBox(height: 2),
            Text('$pct%', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: t.primary)),
            const SizedBox(height: 2),
            Text('₹$amount', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 12, color: t.textSecondary)),
          ]),
        ]),
      );
    }).toList());
  }

  Widget _leaderboardCard(_T t, bool isDark, double minPoints, double myPoints) {
    if (_leaderboard.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
        child: Center(child: Text('No ranked users found for this month.', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary), textAlign: TextAlign.center)),
      );
    }
    final top10 = _leaderboard.take(10).toList();
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        for (int i = 0; i < top10.length; i++) _leaderRow(top10[i], i, top10.length, t, isDark, minPoints),
      ]),
    );
  }

  Widget _leaderRow(Map<String, dynamic> user, int idx, int total, _T t, bool isDark, double minPoints) {
    final rank = (user['rank'] as num?)?.toInt();
    final name = user['name']?.toString() ?? user['username']?.toString() ?? 'User';
    final pts = double.tryParse((user['mission_points'] ?? user['rank_points'] ?? 0).toString()) ?? 0;
    final eligible = minPoints == 0 || pts >= minPoints;
    final isMe = _myRank?['rank'] != null && rank == (_myRank!['rank'] as num?)?.toInt();
    final expectedReward = user['expected_reward']?.toString() ?? '0.00';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? t.meBg : Colors.transparent,
        border: idx < total - 1 ? Border(bottom: BorderSide(color: t.border)) : null,
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: isMe ? t.primary : t.rankBadgeBg, shape: BoxShape.circle),
          child: Center(child: Text(rank?.toString() ?? '—', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14, color: isMe ? Colors.white : t.textSecondary))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: t.text))),
            if (isMe) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('you', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 10, color: t.primary)))],
          ]),
          Text.rich(TextSpan(
            text: '${_fmtNum(pts.toInt())} pts',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary),
            children: eligible ? [] : [
              TextSpan(text: ' · ${_fmtNum((minPoints - pts).toInt())} more to qualify', style: const TextStyle(color: Color(0xFFf97316))),
            ],
          )),
        ])),
        eligible
            ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0x2634C759), borderRadius: BorderRadius.circular(12)), child: Text('₹$expectedReward', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF34C759))))
            : Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0x1Ff97316), shape: BoxShape.circle), child: const Icon(Icons.lock_outline, size: 14, color: Color(0xFFf97316))),
      ]),
    );
  }

  Widget _footerInfo(_T t, String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: t.footerBg, borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 16, color: t.textTertiary),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary, height: 1.5))),
    ]),
  );

  Color _darkenPrimary(Color c) => Color.fromARGB(c.alpha, (c.red * 0.7).toInt(), (c.green * 0.7).toInt(), (c.blue * 0.7).toInt());

  String _monthName(int m) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][m - 1];

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return n.toString();
  }
}
