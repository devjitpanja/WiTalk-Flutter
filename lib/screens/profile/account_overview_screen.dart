import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/verification_badge.dart';

// ─── Cache keys ───────────────────────────────────────────────────────────────
const _kCacheUser = 'account_overview_user_cache_ts';
const _kCacheVerification = 'account_overview_verification_cache_ts';
const _kCacheTtl = Duration(minutes: 5);

// ─── Week helpers ─────────────────────────────────────────────────────────────
const _weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

List<Map<String, String>> _getCurrentWeekDays() {
  final now = DateTime.now();
  final dow = now.weekday; // 1=Mon … 7=Sun
  final monday = now.subtract(Duration(days: dow - 1));
  return List.generate(7, (i) {
    final d = monday.add(Duration(days: i));
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {'date': date, 'label': _weekLabels[i]};
  });
}

List<String> _getLast7DayStrings() =>
    _getCurrentWeekDays().map((d) => d['date']!).toList();

bool _isNonEmpty(dynamic val) {
  if (val == null) return false;
  if (val is String) return val.trim().isNotEmpty;
  if (val is List) return val.isNotEmpty;
  return true;
}

List<dynamic> _parseList(dynamic val) {
  if (val == null) return [];
  if (val is List) return val;
  if (val is String && val.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(val);
      if (parsed is List) return parsed;
    } catch (_) {
      return [val];
    }
  }
  return [];
}

int _calcProfileCompletion(Map<String, dynamic>? user) {
  if (user == null) return 0;
  int score = 0;
  if (_isNonEmpty(user['name'])) score++;
  if (_isNonEmpty(user['username'])) score++;
  if (_isNonEmpty(user['bio'])) score++;
  if (_isNonEmpty(user['profile_pic'])) score++;
  if (_isNonEmpty(user['gender'])) score++;
  if (_isNonEmpty(user['city'])) score++;
  if (_isNonEmpty(user['occupation'])) score++;
  if (_isNonEmpty(user['country'])) score++;
  if (_isNonEmpty(user['birthday'])) score++;
  if (_parseList(user['interests']).isNotEmpty) score++;
  if (_parseList(user['purpose']).isNotEmpty) score++;
  return ((score / 11) * 100).round();
}

// ─── Blinking dot ─────────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  final double size;
  const _BlinkingDot({this.size = 8});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.15, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: Container(width: widget.size, height: widget.size, decoration: const BoxDecoration(color: Color(0xFFFF453A), shape: BoxShape.circle)));
}

// ─── Theme helper ─────────────────────────────────────────────────────────────
class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get card => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => dark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get xpBarBg => dark ? const Color(0xFF252b3b) : const Color(0xFFEAECF2);
  Color get streakDotEmpty => dark ? const Color(0xFF3A2800) : Colors.transparent;
  Color get streakDotEmptyBorder => dark ? const Color(0xFF6D4C00) : const Color(0xFFE65100);
  Color get streakDotFilled => dark ? const Color(0xFFFFA000) : const Color(0xFFF57C00);
  Color get streakNumColor => dark ? const Color(0xFFFFB300) : const Color(0xFFE65100);
  Color get streakSubColor => dark ? const Color(0xFFFF8F00) : const Color(0xFFBF360C);
  Color get logoutIconBg => dark ? const Color(0xFF1a1f2e) : const Color(0xFFFFF0F0);
  Color get listIconBg => primary.withAlpha(0x14);
  Color get switchTrackFalse => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get switchThumbFalse => dark ? const Color(0xFF8E8E93) : Colors.white;
}

// ─── Main screen ─────────────────────────────────────────────────────────────
class AccountOverviewScreen extends ConsumerStatefulWidget {
  const AccountOverviewScreen({super.key});
  @override
  ConsumerState<AccountOverviewScreen> createState() => _AccountOverviewScreenState();
}

class _AccountOverviewScreenState extends ConsumerState<AccountOverviewScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  double _levelProgress = 0;
  Map<String, dynamic> _streakData = {'currentStreak': 0, 'longestStreak': 0, 'last7Qualified': List<bool>.filled(7, false)};
  bool _isVerified = false;
  Map<String, dynamic>? _verificationStatus;
  bool _showLogoutDialog = false;
  bool _loggingOut = false;
  bool _showAccountSwitchDialog = false;
  bool _switchingAccountType = false;
  String _accountType = 'personal';
  bool _hasVisitedTutorial = true;
  bool _hasVisitedLeaderboard = true;
  bool _hasVisitedRewards = true;
  bool _isFetching = false;

  late final List<Map<String, String>> _weekDayLabels;

  @override
  void initState() {
    super.initState();
    _weekDayLabels = _getCurrentWeekDays();
    _loadFromCacheThenRefresh();
    _loadVerificationStatusWithCache();
    _checkProfileClickedStatus();
    _loadVisitedFlags();
    _refreshStreakData();
  }

  // ─── Data loaders ──────────────────────────────────────────────────────────

  Future<void> _loadVisitedFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hasVisitedTutorial = prefs.getBool('hasVisitedTutorial') ?? false;
        _hasVisitedLeaderboard = prefs.getBool('hasVisitedLeaderboard') ?? false;
        _hasVisitedRewards = prefs.getBool('hasVisitedRewards') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _markVisited(String key, void Function(bool) setter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
      if (mounted) setState(() => setter(true));
    } catch (_) {}
  }

  Future<void> _checkProfileClickedStatus() async {}

  Future<void> _loadFromCacheThenRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAt = prefs.getInt(_kCacheUser) ?? 0;
      final hasCache = DateTime.now().millisecondsSinceEpoch - cachedAt < _kCacheTtl.inMilliseconds;
      if (hasCache && prefs.containsKey('aov_userData_name')) {
        // Restore minimal cached state
        setState(() {
          _userData = {
            'name': prefs.getString('aov_userData_name'),
            'username': prefs.getString('aov_userData_username'),
            'profile_pic': prefs.getString('aov_userData_pic'),
            'id': prefs.getString('aov_userData_id'),
            'level': prefs.getInt('aov_userData_level') ?? 1,
            'levelTitle': prefs.getString('aov_userData_levelTitle') ?? 'Newcomer',
            'levelPoints': prefs.getInt('aov_userData_levelPoints') ?? 0,
            'maxLevelPoints': prefs.getInt('aov_userData_maxLevelPoints') ?? 150,
            'is_verified': prefs.getBool('aov_userData_isVerified') ?? false,
            'verification_badge': prefs.getString('aov_userData_badge'),
            'account_type': prefs.getString('aov_userData_accountType') ?? 'personal',
          };
          _levelProgress = (prefs.getDouble('aov_levelProgress') ?? 0);
          _accountType = prefs.getString('aov_accountType') ?? 'personal';
          _loading = false;
        });
        _fetchAndCacheUserData(silent: true);
      } else {
        _fetchAndCacheUserData(silent: false);
      }
    } catch (_) {
      _fetchAndCacheUserData(silent: false);
    }
  }

  Future<void> _fetchAndCacheUserData({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;

      final userRes = await dioClient.get('/v1/user/$uid');
      final user = Map<String, dynamic>.from(userRes.data['data'] as Map);
      if (user['username'] != null) await prefs.setString('username', user['username'].toString());

      // Fallback check for purpose if backend returned empty purpose
      dynamic purposeRaw = user['purpose'];
      final purposeEmpty = purposeRaw == null ||
          (purposeRaw is List && purposeRaw.isEmpty) ||
          (purposeRaw is String && (purposeRaw.trim().isEmpty || purposeRaw == '[]'));
      if (purposeEmpty) {
        try {
          final pRes = await dioClient.get('/v1/user/$uid/purpose-interests-check');
          final pd = pRes.data;
          if (pd?['statusCode'] == 200 && pd?['data']?['hasPurpose'] == true) {
            user['purpose'] = pd['data']['purpose'];
          }
        } catch (_) {}
      }

      Map<String, dynamic> levelData = {
        'currentLevel': 1,
        'levelTitle': 'Newcomer',
        'totalPointsEarned': 0,
        'nextLevelPoints': 150,
        'progressPercentage': 0.0,
      };
      try {
        final lvlRes = await dioClient.get('/v1/levels/user/$uid');
        if (lvlRes.data['success'] == true) levelData = Map<String, dynamic>.from(lvlRes.data['data'] as Map);
      } catch (_) {}

      final fresh = {
        ...user,
        'level': levelData['currentLevel'],
        'levelTitle': levelData['levelTitle'],
        'levelPoints': levelData['totalPointsEarned'],
        'maxLevelPoints': levelData['nextLevelPoints'],
      };
      final freshAccountType = (user['account_type'] as String?) ?? 'personal';
      final freshProgress = (levelData['progressPercentage'] as num?)?.toDouble() ?? 0.0;

      // Persist to prefs
      await prefs.setInt(_kCacheUser, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('aov_userData_name', (fresh['name'] ?? '').toString());
      await prefs.setString('aov_userData_username', (fresh['username'] ?? '').toString());
      await prefs.setString('aov_userData_pic', (fresh['profile_pic'] ?? '').toString());
      await prefs.setString('aov_userData_id', (fresh['id'] ?? '').toString());
      await prefs.setInt('aov_userData_level', (fresh['level'] as num?)?.toInt() ?? 1);
      await prefs.setString('aov_userData_levelTitle', (fresh['levelTitle'] ?? 'Newcomer').toString());
      await prefs.setInt('aov_userData_levelPoints', (fresh['levelPoints'] as num?)?.toInt() ?? 0);
      await prefs.setInt('aov_userData_maxLevelPoints', (fresh['maxLevelPoints'] as num?)?.toInt() ?? 150);
      await prefs.setDouble('aov_levelProgress', freshProgress);
      await prefs.setString('aov_accountType', freshAccountType);

      if (mounted) setState(() {
        _userData = fresh;
        _accountType = freshAccountType;
        _levelProgress = freshProgress;
        if (!silent) _loading = false;
      });
    } catch (_) {
    } finally {
      _isFetching = false;
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVerificationStatusWithCache({bool force = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final cachedAt = prefs.getInt(_kCacheVerification) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - cachedAt < _kCacheTtl.inMilliseconds) {
          if (mounted) setState(() {
            _isVerified = prefs.getBool('aov_isVerified') ?? false;
          });
          return;
        }
      }
      final res = await dioClient.get('/v1/verification/status');
      if (res.data['success'] == true) {
        final status = Map<String, dynamic>.from(res.data['data'] as Map);
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setInt(_kCacheVerification, DateTime.now().millisecondsSinceEpoch);
        await prefs2.setBool('aov_isVerified', status['isVerified'] == true);
        if (mounted) setState(() {
          _isVerified = status['isVerified'] == true;
          _verificationStatus = status;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;

      final weekDates = _getLast7DayStrings();
      final now = DateTime.now();
      final mondayMonth = int.parse(weekDates[0].split('-')[1]);
      final needsPrevMonth = mondayMonth != now.month;

      final results = await Future.wait([
        dioClient.get('/v1/streaks/$uid'),
        dioClient.get('/v1/streaks/$uid/calendar?year=${now.year}&month=${now.month}'),
        if (needsPrevMonth) () {
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          return dioClient.get('/v1/streaks/$uid/calendar?year=$prevYear&month=$prevMonth');
        }(),
      ]);

      final streakRes = results[0];
      final calRes = results[1];

      if (streakRes.data['success'] == true) {
        final allCalDays = <Map<String, dynamic>>[
          if (calRes.data['success'] == true)
            ...(calRes.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          if (results.length > 2 && results[2].data['success'] == true)
            ...(results[2].data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        ];
        final qualified = <String>{
          for (final d in allCalDays)
            if (d['qualified'] == true) d['date'].toString(),
        };
        final data = streakRes.data['data'];
        if (mounted) setState(() {
          _streakData = {
            'currentStreak': (data['currentStreak'] as num?)?.toInt() ?? 0,
            'longestStreak': (data['longestStreak'] as num?)?.toInt() ?? 0,
            'last7Qualified': weekDates.map((d) => qualified.contains(d)).toList(),
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchAndCacheUserData(silent: true),
      _loadVerificationStatusWithCache(),
      _refreshStreakData(),
    ]);
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleAvatarPress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasClickedAvatarProfile', true);
    } catch (_) {}
    if (mounted) {
      await context.push('/edit-profile');
      _onRefresh();
    }
  }

  Future<void> _handleContactSupport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid') ?? 'Not available';
      final email = prefs.getString('email') ?? 'Not available';
      final subject = Uri.encodeComponent('WiTalk Support Request');
      final body = Uri.encodeComponent(
        'Dear WiTalk Support Team,\n\nI need assistance with the following issue:\n\n[Please describe your issue here]\n\n---\nUser ID: $uid\nEmail: $email\n\nThank you!',
      );
      final url = Uri.parse('mailto:support@witalk.in?subject=$subject&body=$body');
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (_) {}
  }

  Future<void> _handleInAppSupport() async {
    Navigator.of(context).pop();
    try {
      final res = await dioClient.get('/v1/user/find/support');
      if (res.data['success'] == true && mounted) {
        final su = Map<String, dynamic>.from(res.data['data'] as Map);
        context.push('/chat/conversation/${su['id']}');
      }
    } catch (_) {}
  }

  Future<void> _confirmLogout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (_) {
      if (mounted) setState(() { _loggingOut = false; _showLogoutDialog = false; });
    }
  }

  Future<void> _confirmAccountTypeSwitch() async {
    final newType = _accountType == 'personal' ? 'professional' : 'personal';
    setState(() => _switchingAccountType = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.put('/v1/user/$uid/account-type', data: {'accountType': newType});
      if (res.data['success'] == true && mounted) {
        setState(() { _accountType = newType; _showAccountSwitchDialog = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Switched to $newType account', style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: const Color(0xFF34C759),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _showAccountSwitchDialog = false);
    } finally {
      if (mounted) setState(() => _switchingAccountType = false);
    }
  }

  void _showSupportSheet(_T t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: t.textTertiary, borderRadius: BorderRadius.circular(2)))),
          Text('Contact Support', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: t.text)),
          const SizedBox(height: 12),
          // In-App Support
          InkWell(
            onTap: () { Navigator.pop(ctx); _handleInAppSupport(); },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0x224A90E2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.chat, size: 26, color: Color(0xFF4A90E2))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('In-App Support', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: t.text)),
                  const SizedBox(height: 2),
                  Text('Chat with @support in the app', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary)),
                ])),
                Icon(Icons.chevron_right, size: 22, color: t.textTertiary),
              ]),
            ),
          ),
          Divider(color: t.border, indent: 64, height: 1),
          // Email Support
          InkWell(
            onTap: () { Navigator.pop(ctx); Future.delayed(const Duration(milliseconds: 200), _handleContactSupport); },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0x1AFF9F0A), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.email, size: 26, color: Color(0xFFFF9F0A))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Email Support', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: t.text)),
                  const SizedBox(height: 2),
                  Text('Send us an email at support@witalk.in', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary)),
                ])),
                Icon(Icons.chevron_right, size: 22, color: t.textTertiary),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    if (_loading) return _buildSkeleton(t);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(children: [
          CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildHeader(t),
                  _buildProfileCard(t, isDark),
                  _buildVerificationBanner(t),
                  _buildGamificationRow(t, isDark),
                  _buildDailyZone(t, isDark),
                  _buildQuickAccess(t),
                  _buildSectionHeader('ACCOUNT', t),
                  _buildListSection(_accountMenuItems(t), t),
                  _buildSectionHeader('PRIVACY', t),
                  _buildListSection(_privacyMenuItems(t), t),
                  _buildSectionHeader('GENERAL', t),
                  _buildListSection(_generalMenuItems(t, isDark), t),
                  _buildLogoutButton(t, isDark),
                  const SizedBox(height: 32),
                ])),
              ],
            ),
          // Dialogs
          if (_showLogoutDialog) _buildLogoutDialog(t),
          if (_showAccountSwitchDialog) _buildAccountSwitchDialog(t),
        ]),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(_T t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Text('Menu', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text, letterSpacing: 0.3)),
      );

  // ─── Profile card ──────────────────────────────────────────────────────────
  Widget _buildProfileCard(_T t, bool isDark) {
    final username = (_userData?['username']?.toString() ?? '').isNotEmpty ? _userData!['username'].toString() : 'user';
    final name = (_userData?['name'] as String? ?? '').isNotEmpty ? _userData!['name'].toString() : username;
    final pic = _userData?['profile_pic']?.toString();
    final level = (_userData?['level'] as num?)?.toInt() ?? 1;
    final levelTitle = _userData?['levelTitle']?.toString() ?? 'Newcomer';
    final levelPoints = (_userData?['levelPoints'] as num?)?.toInt() ?? 0;
    final maxLevelPoints = (_userData?['maxLevelPoints'] as num?)?.toInt() ?? 150;
    final completion = _calcProfileCompletion(_userData);
    final isVerified = _isVerified || (_userData?['is_verified'] == true);
    Map<String, dynamic>? badgeData;
    if (_userData?['verification_badge'] is Map) {
      badgeData = Map<String, dynamic>.from(_userData!['verification_badge'] as Map);
    }

    return GestureDetector(
      onTap: () async {
        await context.push('/profile');
        _onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.border)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(children: [
              // Avatar
              GestureDetector(
                onTap: _handleAvatarPress,
                child: SizedBox(
                  width: 60, height: 60,
                  child: Stack(children: [
                    ClipOval(child: pic != null && pic.isNotEmpty
                        ? CachedNetworkImage(imageUrl: pic, width: 60, height: 60, fit: BoxFit.cover)
                        : Container(width: 60, height: 60, color: t.primary, alignment: Alignment.center,
                            child: Text(username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 22, color: Colors.white)))),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Icon(Icons.edit, size: 9, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text))),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    VerificationBadge(isVerified: isVerified, badge: badgeData, size: 14),
                  ],
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]), borderRadius: BorderRadius.circular(8)),
                    child: Text('Lv.$level', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 10, color: Colors.black)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('@$username · $levelTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Container(height: 6, decoration: BoxDecoration(color: t.xpBarBg, borderRadius: BorderRadius.circular(6)), child: FractionallySizedBox(widthFactor: (_levelProgress / 100).clamp(0.0, 1.0), alignment: Alignment.centerLeft, child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]), borderRadius: BorderRadius.circular(6)))))),
                  const SizedBox(width: 8),
                  Text('$levelPoints/$maxLevelPoints XP', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
                ]),
              ])),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
            ]),
          ),
          if (completion < 100) ...[
            Container(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(children: [
                Expanded(child: Container(height: 3, decoration: BoxDecoration(color: t.xpBarBg, borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(widthFactor: (completion / 100).clamp(0.0, 1.0), alignment: Alignment.centerLeft, child: Container(decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(3)))))),
                const SizedBox(width: 8),
                Text('$completion% profile complete', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.textTertiary)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── Verification banner ───────────────────────────────────────────────────
  Widget _buildVerificationBanner(_T t) {
    final isPending = _verificationStatus?['pendingRequest']?['status'] == 'pending';
    if (_isVerified || isPending) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/id-verification'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: Color(0xFFFF9F0A), width: 3)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFFF9F0A)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Verify your identity to unlock all features', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFFE65100)))),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFFF9F0A)),
        ]),
      ),
    );
  }

  // ─── Streak / gamification row ─────────────────────────────────────────────
  Widget _buildGamificationRow(_T t, bool isDark) {
    final currentStreak = (_streakData['currentStreak'] as int?) ?? 0;
    final longestStreak = (_streakData['longestStreak'] as int?) ?? 0;
    final last7 = (_streakData['last7Qualified'] as List?)?.cast<bool>() ?? List.filled(7, false);
    final weekLabels = _weekDayLabels.map((d) => d['label']!).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: GestureDetector(
        onTap: () => context.push('/streak'),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? [const Color(0xFF1C1000), const Color(0xFF2E1A00), const Color(0xFF3A2200)] : [const Color(0xFFFFF8E1), const Color(0xFFFFE082), const Color(0xFFFFCA28)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$currentStreak', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 30, color: t.streakNumColor, height: 1.2)),
                Text('DAY STREAK', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 10, color: t.streakSubColor, letterSpacing: 1.1)),
              ]),
              const Spacer(),
              Text('🔥', style: TextStyle(fontSize: 36, color: Colors.orange.withValues(alpha: 0.2))),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (int i = 0; i < 7; i++) Column(children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: last7[i] ? t.streakDotFilled : t.streakDotEmpty,
                    border: last7[i] ? null : Border.all(color: t.streakDotEmptyBorder, width: 2),
                  ),
                ),
                const SizedBox(height: 3),
                Text(weekLabels[i], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 10, color: t.streakSubColor)),
              ]),
            ]),
            const SizedBox(height: 6),
            Text('🏅 Best $longestStreak day${longestStreak != 1 ? 's' : ''}', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.streakSubColor)),
          ]),
        ),
      ),
    );
  }

  // ─── Daily zone (Rank + Missions hero cards) ───────────────────────────────
  Widget _buildDailyZone(_T t, bool isDark) => Column(children: [
        // Rank
        _heroCard(
          gradientColors: isDark ? [const Color(0xFF0A1833), const Color(0xFF0F2451), const Color(0xFF132E65)] : [const Color(0xFF1565C0), const Color(0xFF1976D2), const Color(0xFF1E88E5)],
          decorIcon: Icons.military_tech,
          iconColor: const Color(0xFFFFD700),
          title: 'Leaderboard Rank',
          subtitle: '${_userData?['levelTitle'] ?? 'Newcomer'} · Level ${(_userData?['level'] as num?)?.toInt() ?? 1}',
          showDot: !_hasVisitedLeaderboard,
          onTap: () { _markVisited('hasVisitedLeaderboard', (v) => _hasVisitedLeaderboard = v); context.push('/rank'); },
        ),
        // Missions
        _heroCard(
          gradientColors: isDark ? [const Color(0xFF061A0F), const Color(0xFF0A2E1A), const Color(0xFF0E3D22)] : [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF388E3C)],
          decorIcon: Icons.stars,
          iconColor: const Color(0xFFA5D6A7),
          title: 'Daily Missions',
          subtitle: 'Complete tasks · Earn XP rewards',
          showDot: false,
          onTap: () => context.push('/missions'),
        ),
      ]);

  Widget _heroCard({
    required List<Color> gradientColors,
    required IconData decorIcon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool showDot,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            Positioned(right: -8, top: -8, child: Icon(decorIcon, size: 72, color: Colors.white.withValues(alpha: 0.07))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: Icon(decorIcon, size: 24, color: iconColor)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xA6FFFFFF))),
                ])),
                if (showDot) ...[_BlinkingDot(), const SizedBox(width: 6)],
                const Icon(Icons.chevron_right, size: 20, color: Color(0x8CFFFFFF)),
              ]),
            ),
          ]),
        ),
      );

  // ─── Quick access grid ─────────────────────────────────────────────────────
  Widget _buildQuickAccess(_T t) {
    final items = [
      _QuickItem(icon: Icons.card_giftcard, label: 'Rewards', color: const Color(0xFFFF9F0A), bg: const Color(0x1AFF9F0A), showDot: !_hasVisitedRewards, onTap: () { _markVisited('hasVisitedRewards', (v) => _hasVisitedRewards = v); context.push('/rewards'); }),
      _QuickItem(icon: Icons.confirmation_number, label: 'Pass', color: const Color(0xFFF59E0B), bg: const Color(0x1AF59E0B), onTap: () => context.push('/pass')),
      _QuickItem(icon: Icons.account_balance_wallet, label: 'Wallet', color: const Color(0xFF34C759), bg: const Color(0x1A34C759), onTap: () => context.push('/wallet')),
      _QuickItem(icon: Icons.school, label: 'Tutorial', color: const Color(0xFFAF52DE), bg: const Color(0x1AAF52DE), showDot: !_hasVisitedTutorial, onTap: () { _markVisited('hasVisitedTutorial', (v) => _hasVisitedTutorial = v); context.push('/tutorial'); }),
      _QuickItem(icon: Icons.bookmark, label: 'Saved', color: const Color(0xFF007AFF), bg: const Color(0x1A007AFF), onTap: () => context.push('/saved')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('QUICK ACCESS', t),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
        child: Row(children: [
          for (int i = 0; i < items.length; i++) Expanded(child: Container(
            decoration: BoxDecoration(border: i < items.length - 1 ? Border(right: BorderSide(color: t.border)) : null),
            child: GestureDetector(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: items[i].bg, borderRadius: BorderRadius.circular(10)), child: Icon(items[i].icon, size: 19, color: items[i].color)),
                    if (items[i].showDot) Positioned(top: -2, right: -2, child: _BlinkingDot(size: 9)),
                  ]),
                  const SizedBox(height: 6),
                  Text(items[i].label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: t.text)),
                ]),
              ),
            ),
          )),
        ]),
      ),
    ]);
  }

  // ─── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, _T t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: t.textTertiary, letterSpacing: 1.3)),
      );

  // ─── List section ──────────────────────────────────────────────────────────
  Widget _buildListSection(List<_MenuItem> items, _T t) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
        child: Column(children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Container(height: StyleSheet.hairlineWidth, color: t.border),
            _buildListMenuItem(items[i], t),
          ],
        ]),
      );

  Widget _buildListMenuItem(_MenuItem item, _T t) {
    final isSwitch = item.showSwitch;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSwitch ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: t.primary.withAlpha(0x14), borderRadius: BorderRadius.circular(10)),
            child: Icon(item.icon, size: 19, color: t.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: t.text)),
            const SizedBox(height: 2),
            Text(item.description, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
          ])),
          if (item.badge != null) ...[
            Text(item.badge!, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: item.badgeColor ?? t.textTertiary)),
            const SizedBox(width: 4),
          ],
          if (isSwitch)
            Switch(
              value: item.switchValue ?? false,
              onChanged: (_) => item.onSwitchToggle?.call(),
              activeThumbColor: Colors.white,
              activeTrackColor: t.primary,
              inactiveTrackColor: t.switchTrackFalse,
              inactiveThumbColor: t.switchThumbFalse,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            )
          else
            Icon(Icons.chevron_right, size: 20, color: t.textTertiary),
        ]),
      ),
    );
  }

  // ─── Menu item builders ────────────────────────────────────────────────────
  List<_MenuItem> _accountMenuItems(_T t) => [
    _MenuItem(icon: Icons.manage_accounts, title: 'Account', description: 'Personal details, manage account', onTap: () => context.push('/account-settings')),
    _MenuItem(icon: Icons.receipt_long, title: 'Purchases & Subscriptions', description: 'View your paid community purchases', onTap: () => context.push('/purchases')),
  ];

  List<_MenuItem> _privacyMenuItems(_T t) => [
    _MenuItem(icon: Icons.mark_chat_read, title: 'Message Privacy', description: 'Control who can message you', onTap: () => context.push('/settings/message-privacy')),
  ];

  List<_MenuItem> _generalMenuItems(_T t, bool isDark) => [
    _MenuItem(icon: Icons.tune, title: 'Content Preferences', description: 'Manage excluded users', onTap: () => context.push('/settings/content')),
    _MenuItem(icon: Icons.block, title: 'Blocked Accounts', description: 'Manage blocked users', onTap: () => context.push('/blocked-accounts')),
    _MenuItem(icon: Icons.storage, title: 'Storage & Data', description: 'Manage cache & auto-download', onTap: () => context.push('/settings/storage')),
    _MenuItem(icon: Icons.notifications, title: 'Notifications', description: 'Manage notification preferences', onTap: () => context.push('/settings/notifications')),
    _MenuItem(icon: isDark ? Icons.dark_mode : Icons.light_mode, title: 'Dark Mode', description: isDark ? 'Switch to light mode' : 'Switch to dark mode', showSwitch: true, switchValue: isDark, onSwitchToggle: () => ref.read(themeProvider.notifier).toggle()),
    _MenuItem(icon: Icons.person_add, title: 'Invite Friends', description: 'Earn rewards', badge: 'Earn money', badgeColor: const Color(0xFFFF9F0A), onTap: () => context.push('/referral')),
    _MenuItem(icon: Icons.bug_report, title: 'Bugs & Suggestions', description: 'Report bugs or suggest features', onTap: () => context.push('/bugs-suggestions')),
    _MenuItem(icon: Icons.help_outline, title: 'Help Center', description: 'Get support', onTap: () => _showSupportSheet(t)),
  ];

  // ─── Logout button ─────────────────────────────────────────────────────────
  Widget _buildLogoutButton(_T t, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        child: GestureDetector(
          onTap: () => setState(() => _showLogoutDialog = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0x0DA30000), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x30A30000))),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: t.logoutIconBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.logout, size: 20, color: Color(0xFFFF453A)),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Logout', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFFF453A)))),
              const Icon(Icons.chevron_right, size: 19, color: Color(0xFFFF453A)),
            ]),
          ),
        ),
      );

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  Widget _buildLogoutDialog(_T t) => _Dialog(
        t: t,
        title: 'Logout',
        message: 'Are you sure you want to logout?',
        confirmText: 'Logout',
        confirmColor: const Color(0xFFFF453A),
        loading: _loggingOut,
        onConfirm: _confirmLogout,
        onCancel: () => setState(() { _showLogoutDialog = false; _loggingOut = false; }),
      );

  Widget _buildAccountSwitchDialog(_T t) => _Dialog(
        t: t,
        title: 'Switch Account Type',
        message: 'Are you sure you want to switch to a ${_accountType == 'personal' ? 'professional' : 'personal'} account?',
        confirmText: 'Switch',
        loading: _switchingAccountType,
        onConfirm: _confirmAccountTypeSwitch,
        onCancel: () => setState(() => _showAccountSwitchDialog = false),
      );

  // ─── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton(_T t) {
    final skBase = t.dark ? const Color(0xFF1a1f2e) : const Color(0xFFE1E9EE);
    final skHi = t.dark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Shimmer.fromColors(
          baseColor: skBase,
          highlightColor: skHi,
          child: ListView(padding: EdgeInsets.zero, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Container(width: 80, height: 22, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(6)))),
            // Profile card
            Container(margin: const EdgeInsets.fromLTRB(12, 2, 12, 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(18)), child: Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: skHi, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 120, height: 14, color: skHi),
                const SizedBox(height: 8),
                Container(width: 80, height: 11, color: skHi),
                const SizedBox(height: 10),
                Container(height: 6, decoration: BoxDecoration(color: skHi, borderRadius: BorderRadius.circular(4))),
              ])),
            ])),
            // Streak
            Container(margin: const EdgeInsets.fromLTRB(12, 10, 12, 0), height: 130, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(18))),
            // Hero cards
            Container(margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), height: 72, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(16))),
            Container(margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), height: 72, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(16))),
            // Quick grid
            Container(margin: const EdgeInsets.fromLTRB(12, 20, 12, 0), height: 88, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(16))),
            // List
            Container(margin: const EdgeInsets.fromLTRB(12, 28, 12, 0), height: 180, decoration: BoxDecoration(color: skBase, borderRadius: BorderRadius.circular(14))),
          ]),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final bool showDot;
  final VoidCallback onTap;
  const _QuickItem({required this.icon, required this.label, required this.color, required this.bg, this.showDot = false, required this.onTap});
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool showSwitch;
  final bool? switchValue;
  final VoidCallback? onSwitchToggle;
  final String? badge;
  final Color? badgeColor;
  const _MenuItem({required this.icon, required this.title, required this.description, this.onTap, this.showSwitch = false, this.switchValue, this.onSwitchToggle, this.badge, this.badgeColor});
}

// StyleSheet.hairlineWidth equivalent
class StyleSheet {
  static const double hairlineWidth = 0.5;
}

// ─── Dialog overlay ───────────────────────────────────────────────────────────
class _Dialog extends StatelessWidget {
  final _T t;
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;
  final bool loading;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _Dialog({
    required this.t,
    required this.title,
    required this.message,
    required this.confirmText,
    this.confirmColor = const Color(0xFF0A84FF),
    required this.loading,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onCancel,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text)),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!loading) TextButton(onPressed: onCancel, child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: t.textTertiary, fontSize: 15))),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: loading ? null : onConfirm,
                      child: loading
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: confirmColor))
                          : Text(confirmText, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: confirmColor, fontSize: 15)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
