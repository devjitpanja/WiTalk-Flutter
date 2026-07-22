import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
  Color get tabBg => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get progressTrack => dark ? const Color(0xFF2a2f3e) : const Color(0xFFE5E5EA);
  Color get rewardBg => dark ? const Color(0x1FFFD700) : const Color(0x1FCC6600);
  Color get rewardBorder => dark ? const Color(0x40FFD700) : const Color(0x40CC6600);
  Color get rewardText => dark ? const Color(0xFFFFD700) : const Color(0xFFCC6600);
}

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse(v.toString()));

List<Color> _categoryColors(String? cat) {
  switch (cat) {
    case 'engagement': return [const Color(0xFFFF6B9D), const Color(0xFFC44569)];
    case 'posts': return [const Color(0xFF4A90E2), const Color(0xFF357ABD)];
    case 'social': return [const Color(0xFF00B894), const Color(0xFF00916E)];
    case 'calls': return [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)];
    default: return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
  }
}

const _kMilestoneConfig = {
  'adda_time_milestones': {
    'title': 'Adda Time Challenge',
    'description': 'Spend time in Addas today — hit each milestone to earn XP',
    'icon': 'mic',
    'colors': [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
  },
  'speaking_milestones': {
    'title': 'Speaking Challenge',
    'description': 'Speak on stage in Addas today — hit each milestone to earn XP',
    'icon': 'record-voice-over',
    'colors': [Color(0xFF00CEC9), Color(0xFF00B894)],
  },
};

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});
  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _lifetime = [];
  Map<String, dynamic>? _stats;
  String? _userId;
  String _activeTab = 'daily';
  bool _isRating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool background = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (mounted) setState(() => _userId = uid);

      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version;

      final results = await Future.wait([
        dioClient.get('/v1/missions/user/$uid?appVersion=$appVersion'),
        dioClient.get('/v1/missions/user/$uid/stats'),
      ]);
      final mRes = results[0];
      final sRes = results[1];
      if (mRes.data['success'] == true) {
        if (mounted) {
          setState(() {
            _daily = List<Map<String, dynamic>>.from(
                (mRes.data['data']['daily'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
            _lifetime = List<Map<String, dynamic>>.from(
                (mRes.data['data']['lifetime'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
          });
        }
      }
      if (sRes.data['success'] == true && mounted) {
        setState(() => _stats = Map<String, dynamic>.from(sRes.data['data'] as Map));
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _onRefresh() async => _load();

  void _applyCollect(String id) {
    void apply(List<Map<String, dynamic>> list) {
      for (int i = 0; i < list.length; i++) {
        if (list[i]['missionId'].toString() == id) {
          list[i] = {...list[i], 'isCollected': true, 'canCollect': false, 'status': 'completed'};
        }
      }
    }
    setState(() { apply(_daily); apply(_lifetime); });
  }

  Future<void> _collect(Map<String, dynamic> mission) async {
    final id = mission['missionId'].toString();
    final prevDaily = List<Map<String, dynamic>>.from(_daily.map((e) => Map<String, dynamic>.from(e)));
    final prevLifetime = List<Map<String, dynamic>>.from(_lifetime.map((e) => Map<String, dynamic>.from(e)));
    _applyCollect(id);
    try {
      final res = await dioClient.post('/v1/missions/collect', data: {'userId': _userId, 'missionId': id});
      if (res.data['success'] == true && mounted) {
        final data = res.data['data'] as Map?;
        final pts = data?['pointsAwarded'] ?? 0;
        final leveledUp = data?['leveledUp'] == true;
        _showSnackbar(
          leveledUp
              ? '🎉 Collected $pts XP! Level Up to ${data?['newLevel']} - ${data?['newLevelTitle']}!'
              : '✅ Collected $pts XP!',
          bgColor: Colors.white,
          textColor: Colors.black,
          duration: Duration(seconds: leveledUp ? 4 : 2),
        );
        _load(background: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _daily = prevDaily; _lifetime = prevLifetime; });
        _showSnackbar(
          (e as dynamic).response?.data?['message'] ?? 'Failed to collect reward',
          bgColor: const Color(0xFFFF453A),
          textColor: Colors.white,
        );
        _load(background: true);
      }
    }
  }

  Future<void> _handlePlaystoreReview() async {
    const url = 'https://play.google.com/store/apps/details?id=com.witalk';
    try {
      final startTime = DateTime.now();
      setState(() => _isRating = true);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

      // Poll until app returns to foreground (approximated via a short delay)
      // Real AppState detection would need a native channel; this is a reasonable approximation
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _isRating = false);

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed >= 8000) {
        await dioClient.post('/v1/missions/update-progress', data: {
          'userId': _userId,
          'targetType': 'playstore_review',
          'incrementBy': 1,
        });
        _load();
        _showSnackbar('⭐ Thanks for your review! Collect your 100 XP reward.', bgColor: const Color(0xFF00B894), textColor: Colors.white, duration: const Duration(seconds: 3));
      } else {
        _showSnackbar('✍️ Write a helpful review sharing what you love about WiTalk!', bgColor: const Color(0xFFFF9500), textColor: Colors.white, duration: const Duration(seconds: 3));
      }
    } catch (_) {
      if (mounted) setState(() => _isRating = false);
    }
  }

  void _showSnackbar(String msg, {required Color bgColor, required Color textColor, Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontFamily: 'Outfit', color: textColor)),
      backgroundColor: bgColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> missions) {
    final copy = [...missions];
    copy.sort((a, b) {
      final ac = a['canCollect'] == true, bc = b['canCollect'] == true;
      final ai = a['isCollected'] == true, bi = b['isCollected'] == true;
      if (ac && !bc) return -1;
      if (!ac && bc) return 1;
      if (!ac && !ai && (bi || bc)) return -1;
      if ((ai || ac) && !bc && !bi) return 1;
      if (ai && !bi) return 1;
      if (!ai && bi) return -1;
      return 0;
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    if (_loading) {
      return Scaffold(backgroundColor: t.bg, body: Center(child: CircularProgressIndicator(color: t.primary)));
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(bottom: BorderSide(color: isDark ? Colors.transparent : t.border, width: isDark ? 0 : 1)),
          ),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
            Expanded(child: Text('Missions', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: t.text))),
            GestureDetector(onTap: _onRefresh, child: Icon(Icons.refresh, color: t.text, size: 24)),
          ]),
        ),
        // Stats card
        if (_stats != null) _statsCard(t, isDark),
        // Tab bar
        _tabBar(t, isDark),
        // Content
        Expanded(child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _onRefresh),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                    child: Text(
                      _activeTab == 'daily'
                          ? 'Complete daily missions to earn bonus XP. Resets every 24 hours.'
                          : 'Long-term achievements that unlock as you progress.',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textSecondary, height: 1.4),
                    ),
                  ),
                  if (_activeTab == 'daily') ...[
                    if (_daily.isEmpty) _empty(t, Icons.check_circle, 'No daily missions available')
                    else ...[
                      ..._sort(_daily).where((m) => m['milestoneGroup'] == null).map((m) => _missionCard(m, t, isDark)),
                      ..._groupMilestones(_sort(_daily).where((m) => m['milestoneGroup'] != null).toList(), t, isDark),
                    ],
                  ] else ...[
                    if (_lifetime.isEmpty) _empty(t, Icons.stars, 'No lifetime missions available')
                    else ..._sort(_lifetime).map((m) => _missionCard(m, t, isDark)),
                  ],
                ]),
              ),
            ),
          ],
        )),
      ])),
    );
  }

  Widget _statsCard(_T t, bool isDark) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark ? [const Color(0xFF1e2330), const Color(0xFF181c28)] : [const Color(0xFFF8F9FA), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: isDark ? null : Border.all(color: t.border),
    ),
    padding: const EdgeInsets.all(20),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _statItem(_stats!['completed_missions']?.toString() ?? '0', 'Completed', t),
      Container(width: 1, height: 40, color: t.border),
      _statItem(_stats!['in_progress_missions']?.toString() ?? '0', 'In Progress', t),
      Container(width: 1, height: 40, color: t.border),
      _statItem(_stats!['total_points_from_missions']?.toString() ?? '0', 'Total XP', t, color: t.rewardText),
    ]),
  );

  Widget _statItem(String value, String label, _T t, {Color? color}) => Column(children: [
    Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 24, color: color ?? t.text)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textSecondary)),
  ]);

  Widget _tabBar(_T t, bool isDark) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    decoration: BoxDecoration(
      color: t.tabBg,
      borderRadius: BorderRadius.circular(12),
      border: isDark ? null : Border.all(color: t.border),
    ),
    clipBehavior: Clip.hardEdge,
    child: Row(children: [
      _tabBtn('daily', 'Daily', Icons.today, _daily.length, t, isDark),
      _tabBtn('lifetime', 'Lifetime', Icons.stars, _lifetime.length, t, isDark),
    ]),
  );

  Widget _tabBtn(String id, String label, IconData icon, int count, _T t, bool isDark) {
    final isActive = _activeTab == id;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? t.rewardText : Colors.transparent, width: 3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: isActive ? t.rewardText : t.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, fontSize: 14, color: isActive ? t.rewardText : t.textSecondary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11, color: Colors.black)),
          ),
        ]),
      ),
    ));
  }

  Widget _missionCard(Map<String, dynamic> m, _T t, bool isDark) {
    final canCollect = m['canCollect'] == true;
    final isCollected = m['isCollected'] == true;
    final pct = (_n(m['progressPercentage']) ?? 0).toDouble().clamp(0.0, 100.0);
    final colors = _categoryColors(m['category']?.toString());
    final targetType = m['targetType']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors), shape: BoxShape.circle),
          child: Icon(_iconForKey(m['icon']?.toString()), size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        // Info + progress
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['title']?.toString() ?? '', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: t.text)),
          const SizedBox(height: 3),
          Text(m['description']?.toString() ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Container(
              height: 5,
              decoration: BoxDecoration(color: t.progressTrack, borderRadius: BorderRadius.circular(2.5)),
              child: FractionallySizedBox(
                widthFactor: pct / 100,
                alignment: Alignment.centerLeft,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(2.5))),
              ),
            )),
            const SizedBox(width: 6),
            Text('${_n(m['currentProgress']) ?? 0}/${_n(m['targetValue']) ?? 1}',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 10, color: t.textTertiary)),
          ]),
        ])),
        const SizedBox(width: 10),
        // Right action
        if (canCollect)
          GestureDetector(
            onTap: () => _collect(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(children: [
                Icon(Icons.card_giftcard, size: 16, color: Colors.black),
                SizedBox(width: 4),
                Text('Collect', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black)),
              ]),
            ),
          )
        else if (isCollected)
          Column(children: [
            const Icon(Icons.check_circle, size: 20, color: Color(0xFF00B894)),
            const SizedBox(height: 2),
            const Text('Collected', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 9, color: Color(0xFF00B894))),
          ])
        else if (targetType == 'playstore_review')
          _specialActionColumn(m, t, isDark,
            actionColors: _isRating ? [const Color(0xFF888888), const Color(0xFF555555)] : [const Color(0xFF00C851), const Color(0xFF007E33)],
            icon: Icons.star,
            label: _isRating ? 'Waiting...' : 'Rate Now',
            loading: _isRating,
            onTap: _handlePlaystoreReview,
          )
        else if (targetType == 'watch_rewarded_ad')
          _specialActionColumn(m, t, isDark,
            actionColors: [const Color(0xFF6C5CE7), const Color(0xFF4A00E0)],
            icon: Icons.play_circle_filled,
            label: 'Watch Ad',
            loading: false,
            onTap: () => _showSnackbar('⚠️ Ad not available right now, try again later.',
                bgColor: const Color(0xFFFF453A), textColor: Colors.white),
          )
        else if (targetType == 'instagram_poster')
          _specialActionColumn(m, t, isDark,
            actionColors: [const Color(0xFFE1306C), const Color(0xFFC13584)],
            icon: Icons.share,
            label: 'Start',
            loading: false,
            onTap: () => _showSnackbar('Instagram poster coming soon!',
                bgColor: const Color(0xFFFF9500), textColor: Colors.white),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: t.rewardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.rewardBorder)),
            child: Column(children: [
              Icon(Icons.stars, size: 14, color: t.rewardText),
              Text('+${m['rewardPoints'] ?? 0}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11, color: t.rewardText)),
            ]),
          ),
      ]),
    );
  }

  Widget _specialActionColumn(
    Map<String, dynamic> m, _T t, bool isDark, {
    required List<Color> actionColors,
    required IconData icon,
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return Column(children: [
      // Reward badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: t.rewardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.rewardBorder)),
        child: Column(children: [
          Icon(Icons.stars, size: 12, color: t.rewardText),
          Text('+${m['rewardPoints'] ?? 0}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 10, color: t.rewardText)),
        ]),
      ),
      const SizedBox(height: 6),
      // Action button
      GestureDetector(
        onTap: loading ? null : onTap,
        child: Opacity(
          opacity: loading ? 0.7 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: actionColors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (loading) ...[
                const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ] else ...[
                Icon(icon, size: 13, color: Colors.white),
              ],
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)),
            ]),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _groupMilestones(List<Map<String, dynamic>> milestones, _T t, bool isDark) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in milestones) {
      final g = m['milestoneGroup'].toString();
      groups.putIfAbsent(g, () => []);
      groups[g]!.add(m);
    }
    return groups.entries.map((e) => _milestoneGroupCard(e.key, e.value, t, isDark)).toList();
  }

  Widget _milestoneGroupCard(String key, List<Map<String, dynamic>> ms, _T t, bool isDark) {
    final cfg = _kMilestoneConfig[key] ?? {
      'title': 'Challenge',
      'description': 'Hit each milestone to earn XP',
      'icon': 'star',
      'colors': [const Color(0xFFA29BFE), const Color(0xFF6C5CE7)],
    };
    final sorted = [...ms]..sort((a, b) => (_n(a['targetValue']) ?? 0).compareTo(_n(b['targetValue']) ?? 0));
    final maxTarget = (_n(sorted.last['targetValue']) ?? 1).toDouble();
    final currentProgress = sorted
        .map((m) => _n(m['currentProgress']) ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final overallPct = (currentProgress / maxTarget).clamp(0.0, 1.0);
    final colors = (cfg['colors'] as List).cast<Color>();
    final title = cfg['title'] as String;
    final desc = cfg['description'] as String;
    final iconKey = cfg['icon'] as String;

    final activeMilestone = sorted.firstWhere((m) => m['isCollected'] != true, orElse: () => {});
    final allCollected = activeMilestone.isEmpty;

    String fmt(num m) => m >= 60 ? '${(m / 60).round()}h' : '${m.round()}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors), shape: BoxShape.circle),
            child: Icon(_iconForKey(iconKey), size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: t.text)),
            Text(desc, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textSecondary)),
          ])),
          if (!allCollected && activeMilestone.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: t.rewardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.rewardBorder)),
              child: Column(children: [
                Icon(Icons.stars, size: 12, color: t.rewardText),
                Text('+${activeMilestone['rewardPoints'] ?? 0}',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 10, color: t.rewardText)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        // Progress label row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${currentProgress.round()} min today', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w600, color: t.textTertiary)),
          Text('${maxTarget.round()} min', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w600, color: t.textTertiary)),
        ]),
        const SizedBox(height: 6),
        // Progress bar with milestone dots
        SizedBox(height: 16, child: Stack(clipBehavior: Clip.none, children: [
          // Track + fill
          Positioned(top: 4, left: 0, right: 0, child: Container(
            height: 8,
            decoration: BoxDecoration(color: isDark ? const Color(0xFF2a2f3e) : t.border, borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.hardEdge,
            child: FractionallySizedBox(
              widthFactor: overallPct,
              alignment: Alignment.centerLeft,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(4))),
            ),
          )),
          // Milestone dots
          ...sorted.map((m) {
            final pct = (_n(m['targetValue']) ?? 0) / maxTarget;
            final reached = currentProgress >= (_n(m['targetValue']) ?? 0);
            final isCollected = m['isCollected'] == true;
            final dotColor = isCollected
                ? const Color(0xFF00B894)
                : reached ? const Color(0xFFFFD700) : (isDark ? const Color(0xFF3a3f52) : const Color(0xFFD0D0D0));
            final borderColor = isCollected
                ? const Color(0xFF00916E)
                : reached ? const Color(0xFFFFA500) : (isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB));
            return Positioned(
              left: null,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Align(alignment: Alignment.centerRight, child: Transform.translate(
                  offset: const Offset(-7, 0),
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2)),
                    child: isCollected ? const Icon(Icons.check, size: 7, color: Colors.white) : null,
                  ),
                )),
              ),
            );
          }),
        ])),
        // Time labels
        SizedBox(height: 20, child: Stack(children: [
          ...sorted.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            final pct = (_n(m['targetValue']) ?? 0) / maxTarget;
            final reached = currentProgress >= (_n(m['targetValue']) ?? 0);
            final isLast = idx == sorted.length - 1;
            final labelColor = reached ? t.rewardText : t.textTertiary;
            return Positioned(
              left: isLast ? null : null,
              right: isLast ? 0 : null,
              child: FractionallySizedBox(
                widthFactor: isLast ? null : pct,
                child: Align(
                  alignment: isLast ? Alignment.centerRight : (idx == 0 ? Alignment.centerLeft : Alignment.centerRight),
                  child: Transform.translate(
                    offset: Offset(isLast ? 0 : (idx == 0 ? 0 : -10), 0),
                    child: Text(fmt(_n(m['targetValue']) ?? 0),
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 9, color: labelColor)),
                  ),
                ),
              ),
            );
          }),
        ])),
        // Bottom action row
        if (allCollected || activeMilestone['canCollect'] == true) ...[
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? const Color(0x0FFFFFFF) : const Color(0x0F000000)))),
            child: Row(
              mainAxisAlignment: allCollected ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              children: allCollected
                  ? [
                      Row(children: [
                        const Icon(Icons.emoji_events, size: 16, color: Color(0xFF00B894)),
                        const SizedBox(width: 6),
                        const Text('All milestones complete!', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF00B894))),
                      ]),
                      const Icon(Icons.check_circle, size: 20, color: Color(0xFF00B894)),
                    ]
                  : [
                      GestureDetector(
                        onTap: () => _collect(activeMilestone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(children: [
                            Icon(Icons.card_giftcard, size: 13, color: Colors.black),
                            SizedBox(width: 4),
                            Text('Collect', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 11, color: Colors.black)),
                          ]),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _empty(_T t, IconData icon, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 48, color: t.textTertiary),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
    ]),
  );

  IconData _iconForKey(String? key) {
    if (key == null) return Icons.star;
    const map = {
      'star': Icons.star,
      'mic': Icons.mic,
      'people': Icons.people,
      'article': Icons.article,
      'record-voice-over': Icons.record_voice_over,
      'today': Icons.today,
      'chat': Icons.chat,
      'person-add': Icons.person_add,
      'share': Icons.share,
      'play-circle-filled': Icons.play_circle_filled,
    };
    return map[key] ?? Icons.star;
  }
}
