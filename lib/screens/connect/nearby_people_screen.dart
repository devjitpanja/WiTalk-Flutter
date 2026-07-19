import 'dart:convert';
import 'package:flutter/material.dart';
import 'discover_all_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';

// ─── Data helpers ─────────────────────────────────────────────────────────────

List<dynamic> _parseArr(dynamic v) {
  if (v == null) return [];
  if (v is List) return v;
  if (v is String && v.isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return [];
}

int? _calcAge(dynamic birthday) {
  if (birthday == null) return null;
  try {
    final bd = DateTime.parse(birthday.toString());
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age;
  } catch (_) {
    return null;
  }
}

bool _isBirthdayToday(dynamic birthday) {
  if (birthday == null) return false;
  try {
    final bd = DateTime.parse(birthday.toString());
    final now = DateTime.now();
    return bd.month == now.month && bd.day == now.day;
  } catch (_) {
    return false;
  }
}

double _matchScore(Map<String, dynamic> user, Map<String, dynamic>? me) {
  if (me == null) return 0;
  final myInterests =
      _parseArr(me['interests']).map((e) => e.toString().toLowerCase()).toSet();
  final myPurpose =
      _parseArr(me['purpose']).map((e) => e.toString().toLowerCase()).toSet();
  final uInterests =
      _parseArr(user['interests']).map((e) => e.toString().toLowerCase()).toSet();
  final uPurpose =
      _parseArr(user['purpose']).map((e) => e.toString().toLowerCase()).toSet();
  final commonI = myInterests.intersection(uInterests).length;
  final commonP = myPurpose.intersection(uPurpose).length;
  int pct = 0;
  if (myInterests.isNotEmpty && myPurpose.isNotEmpty) {
    pct = ((commonI / myInterests.length) * 60 +
            (commonP / myPurpose.length) * 40)
        .round();
  } else if (myInterests.isNotEmpty) {
    pct = ((commonI / myInterests.length) * 100).round();
  } else if (myPurpose.isNotEmpty) {
    pct = ((commonP / myPurpose.length) * 100).round();
  }
  return pct.clamp(0, 99).toDouble();
}

List<String> _commonInterests(
    Map<String, dynamic> user, Map<String, dynamic>? me) {
  if (me == null) return [];
  final myInterests =
      _parseArr(me['interests']).map((e) => e.toString().toLowerCase()).toSet();
  return _parseArr(user['interests'])
      .where((e) => myInterests.contains(e.toString().toLowerCase()))
      .map((e) => e.toString())
      .toList();
}

String _fmtDist(dynamic d) {
  final val = (d as num?)?.toDouble();
  if (val == null) return '';
  if (val < 1) return '${(val * 1000).round()}m';
  return '${val.toStringAsFixed(1)}km';
}

String _shortenLabel(String label) {
  const map = {
    'active chatting': 'Chatting',
    'open to voice calls': 'Voice Calls',
    'open to video calls': 'Video Calls',
    'random chat conversations': 'Random Chat',
    'making friends': 'Friends',
    'looking for friends': 'Friends',
    'study buddy': 'Study',
    'language exchange': 'Language',
  };
  return map[label.toLowerCase()] ?? label;
}

// Public aliases so DiscoverAllScreen can reuse these helpers
List<dynamic> nearbyParseArr(dynamic v) => _parseArr(v);
int? nearbyCalcAge(dynamic birthday) => _calcAge(birthday);
String nearbyFmtDist(dynamic d) => _fmtDist(d);

// ─── Groups ───────────────────────────────────────────────────────────────────

class _UserGroups {
  final List<Map<String, dynamic>> catchUp;
  final List<Map<String, dynamic>> onlineNearby;
  final List<Map<String, dynamic>> bestMatches;
  final List<Map<String, dynamic>> sharedVibes;
  final List<Map<String, dynamic>> sameAge;
  final List<Map<String, dynamic>> nearby;
  final List<Map<String, dynamic>> others;

  const _UserGroups({
    required this.catchUp,
    required this.onlineNearby,
    required this.bestMatches,
    required this.sharedVibes,
    required this.sameAge,
    required this.nearby,
    required this.others,
  });

  bool get isEmpty =>
      catchUp.isEmpty &&
      onlineNearby.isEmpty &&
      bestMatches.isEmpty &&
      sharedVibes.isEmpty &&
      sameAge.isEmpty &&
      nearby.isEmpty &&
      others.isEmpty;
}

_UserGroups _groupUsers(
    List<dynamic> users, List<dynamic> birthdays, Map<String, dynamic>? me) {
  final catchUp = <Map<String, dynamic>>[];
  final onlineNearby = <Map<String, dynamic>>[];
  final bestMatches = <Map<String, dynamic>>[];
  final sharedVibes = <Map<String, dynamic>>[];
  final sameAge = <Map<String, dynamic>>[];
  final nearby = <Map<String, dynamic>>[];
  final others = <Map<String, dynamic>>[];

  final meAge = me != null ? _calcAge(me['birthday']) : null;

  // Birthday users (from dedicated endpoint or detected from nearby)
  final catchUpIds = <String>{};
  for (final raw in birthdays) {
    final u = raw as Map<String, dynamic>;
    final uid = (u['uid'] ?? u['id'] ?? '').toString();
    if (uid.isNotEmpty && !catchUpIds.contains(uid)) {
      catchUp.add(u);
      catchUpIds.add(uid);
    }
  }
  // Also check nearby list for birthday today
  for (final raw in users) {
    final u = raw as Map<String, dynamic>;
    final uid = (u['uid'] ?? u['id'] ?? '').toString();
    if (catchUpIds.contains(uid)) continue;
    if (_isBirthdayToday(u['birthday'])) {
      catchUp.add(u);
      catchUpIds.add(uid);
    }
  }

  final diffMs = (u) {
    final ls = u['last_seen'];
    if (ls == null) return double.infinity;
    try {
      return DateTime.now()
          .difference(DateTime.parse(ls.toString()))
          .inMilliseconds
          .toDouble();
    } catch (_) {
      return double.infinity;
    }
  };

  for (final raw in users) {
    final u = raw as Map<String, dynamic>;
    final uid = (u['uid'] ?? u['id'] ?? '').toString();
    if (catchUpIds.contains(uid)) continue;
    final isOnline = u['is_online'] == true;
    final isActiveToday = isOnline || diffMs(u) < 86400000;
    final pct = _matchScore(u, me);
    final ci = _commonInterests(u, me);
    final cp = me != null
        ? _parseArr(me['purpose'])
            .where((p) => _parseArr(u['purpose']).any(
                (up) => up.toString().toLowerCase() == p.toString().toLowerCase()))
            .toList()
        : [];
    final uAge = _calcAge(u['birthday']);
    final ageDiff =
        (meAge != null && uAge != null) ? (meAge - uAge).abs() : 999;
    final dist = (u['distance'] as num?)?.toDouble() ?? double.infinity;

    if (isActiveToday) {
      onlineNearby.add({...u, '_pct': pct, '_ci': ci, '_isActiveToday': true});
    } else if ((cp.isNotEmpty && ci.length >= 1) || ci.length >= 4) {
      bestMatches.add({...u, '_pct': pct, '_ci': ci});
    } else if (ci.length >= 2) {
      sharedVibes.add({...u, '_pct': pct, '_ci': ci});
    } else if (ageDiff <= 3) {
      sameAge.add({...u, '_pct': pct, '_ci': ci});
    } else if (dist <= 10) {
      nearby.add({...u, '_pct': pct, '_ci': ci});
    } else {
      others.add({...u, '_pct': pct, '_ci': ci});
    }
  }

  onlineNearby.sort((a, b) {
    final aOnline = a['is_online'] == true ? 0 : 1;
    final bOnline = b['is_online'] == true ? 0 : 1;
    if (aOnline != bOnline) return aOnline.compareTo(bOnline);
    return ((a['distance'] as num?) ?? 999)
        .compareTo((b['distance'] as num?) ?? 999);
  });

  return _UserGroups(
    catchUp: catchUp,
    onlineNearby: onlineNearby.take(20).toList(),
    bestMatches: bestMatches,
    sharedVibes: sharedVibes,
    sameAge: sameAge,
    nearby: nearby,
    others: others,
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NearbyPeopleScreen extends ConsumerStatefulWidget {
  const NearbyPeopleScreen({super.key});

  @override
  ConsumerState<NearbyPeopleScreen> createState() => _NearbyPeopleScreenState();
}

class _NearbyPeopleScreenState extends ConsumerState<NearbyPeopleScreen> {
  bool _loading = true;
  bool _permDenied = false;
  bool _isLocationCached = false;
  int _cacheAgeMinutes = 0;
  List<dynamic> _users = [];
  List<dynamic> _birthdays = [];
  Map<String, dynamic>? _me;
  _UserGroups? _groups;

  @override
  void initState() {
    super.initState();
    _loadFiltersAndFetch();
  }

  Future<void> _loadFiltersAndFetch() async {
    // Filters are loaded by the provider; fetch immediately
    await _fetchNearbyUsers();
  }

  Future<void> _fetchNearbyUsers({bool quickMode = false}) async {
    if (!mounted) return;
    setState(() { _loading = true; _permDenied = false; });

    try {
      // Check/request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _permDenied = true; _loading = false; });
        return;
      }

      // Phase 1: serve from cache immediately
      final loc = await locationService.getLocation(
        forceRefresh: quickMode,
        quickMode: quickMode,
      );
      final cacheAge = (DateTime.now().millisecondsSinceEpoch - loc.timestamp) ~/
          60000;

      final uid = ref.read(authProvider).uid ?? '';
      final filter = ref.read(nearbyFilterProvider);

      final results = await Future.wait([
        dioClient.get(AppEndpoints.nearbyPeople, queryParameters: {
          'uid': uid,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'radius': filter.maxDistanceKm,
        }),
        dioClient.get(AppEndpoints.nearbyBirthdays, queryParameters: {
          'uid': uid,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'state': loc.state ?? '',
        }),
        dioClient.get(AppEndpoints.userProfile(uid)),
      ]);

      List users = _extractUsers(results[0].data);
      List birthdays = _extractUsers(results[1].data);
      Map<String, dynamic>? me;
      final meRes = results[2].data;
      if (meRes is Map) {
        final u = meRes['user'] ?? meRes['data'];
        if (u is Map) me = Map<String, dynamic>.from(u);
      }

      final filtered = _applyFilter(users, filter);

      if (mounted) {
        setState(() {
          _users = users;
          _birthdays = birthdays;
          _me = me;
          _groups = _groupUsers(filtered, birthdays, me);
          _isLocationCached = loc.source != 'gps';
          _cacheAgeMinutes = cacheAge;
          _loading = false;
        });
      }

      // Phase 2 (background): if we served cached coords, silently refresh
      if (loc.source != 'gps' && !quickMode) {
        _silentRefresh(uid, loc.latitude, loc.longitude, filter);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _groups = _UserGroups(
              catchUp: [],
              onlineNearby: [],
              bestMatches: [],
              sharedVibes: [],
              sameAge: [],
              nearby: [],
              others: []);
        });
      }
    }
  }

  Future<void> _silentRefresh(
      String uid, double oldLat, double oldLon, NearbyFilterState filter) async {
    try {
      final fresh = await locationService.getLocation(forceRefresh: true);
      // Only re-fetch if moved >~100m (0.001 deg)
      final latDiff = (fresh.latitude - oldLat).abs();
      final lonDiff = (fresh.longitude - oldLon).abs();
      if (latDiff < 0.001 && lonDiff < 0.001) return;

      final results = await Future.wait([
        dioClient.get(AppEndpoints.nearbyPeople, queryParameters: {
          'uid': uid,
          'latitude': fresh.latitude,
          'longitude': fresh.longitude,
          'radius': filter.maxDistanceKm,
        }),
        dioClient.get(AppEndpoints.nearbyBirthdays, queryParameters: {
          'uid': uid,
          'latitude': fresh.latitude,
          'longitude': fresh.longitude,
          'state': fresh.state ?? '',
        }),
      ]);
      final users = _extractUsers(results[0].data);
      final birthdays = _extractUsers(results[1].data);
      final filtered = _applyFilter(users, filter);
      if (mounted) {
        setState(() {
          _users = users;
          _birthdays = birthdays;
          _groups = _groupUsers(filtered, birthdays, _me);
          _isLocationCached = false;
          _cacheAgeMinutes = 0;
        });
      }
    } catch (_) {}
  }

  List<dynamic> _extractUsers(dynamic resData) {
    if (resData is Map) {
      final d = resData['data'];
      if (d is List) return d;
      if (d is Map) {
        return (d['users'] as List?) ?? (d['data'] as List?) ?? [];
      }
      return (resData['users'] as List?) ?? [];
    }
    return [];
  }

  List<dynamic> _applyFilter(List<dynamic> users, NearbyFilterState filter) {
    return users.where((raw) {
      final u = raw as Map<String, dynamic>;
      if (filter.gender != 'all') {
        final g = (u['gender'] as String?)?.toLowerCase() ?? '';
        if (g != filter.gender) return false;
      }
      final age = _calcAge(u['birthday']);
      if (age != null && (age < filter.minAge || age > filter.maxAge)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _applyFiltersLocally() {
    final filter = ref.read(nearbyFilterProvider);
    setState(() =>
        _groups = _groupUsers(_applyFilter(_users, filter), _birthdays, _me));
  }

  Future<void> _refresh() async {
    setState(() { _users = []; _birthdays = []; _groups = null; });
    await _fetchNearbyUsers(quickMode: true);
  }

  void _showProfilePreview(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _ProfilePreviewSheet(user: user, me: _me,
          onOpenProfile: () {
            Navigator.of(context).pop();
            context.push('/user/${user['id'] ?? user['uid']}');
          }),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    List<Map<String, dynamic>> users, {
    required IconData icon,
    required Color color,
    required String title,
    required bool isBirthday,
    required bool liveDot,
    VoidCallback? onViewAll,
  }) {
    if (users.isEmpty) return [];
    Widget cardFor(Map<String, dynamic> u) => NearbyUserCard(
          user: u,
          isBirthday: isBirthday,
          onTap: (u) => _showProfilePreview(context, u),
          onSayHi: (u) => context.push('/user/${u['id'] ?? u['uid']}'),
        );
    return [
      _SectionBlock(
        icon: icon,
        iconColor: color,
        title: title,
        count: users.length,
        liveDot: liveDot,
        single: users.length == 1,
        children: users.map(cardFor).toList(),
        wide: isBirthday,
        onViewAll: onViewAll,
      ),
    ];
  }

  void _showFilterSheet() {
    final filter = ref.read(nearbyFilterProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        gender: filter.gender,
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        onApply: (g, min, max) {
          ref.read(nearbyFilterProvider.notifier).update(
              gender: g, minAge: min, maxAge: max);
          _applyFiltersLocally();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, i) => Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.border,
          child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              height: 160,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14))),
        ),
      );
    }

    if (_permDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_off,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('Location Permission Required',
                style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Enable location to discover people near you.',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: AppColors.textTertiary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                setState(() { _permDenied = false; _loading = true; });
                _fetchNearbyUsers();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Open Settings',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    final grp = _groups;
    if (grp == null || grp.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              const Column(children: [
                Icon(Icons.people_outline,
                    size: 64, color: AppColors.textTertiary),
                SizedBox(height: 16),
                Text('No one nearby right now',
                    style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                SizedBox(height: 8),
                Text('Try expanding your search radius',
                    style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Outfit',
                        color: AppColors.textTertiary)),
              ]),
            ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32, top: 4),
        children: [
              // Stale cache banner
              if (_isLocationCached && _cacheAgeMinutes >= 5)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Showing results from $_cacheAgeMinutes min ago · Updating…',
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          color: AppColors.textTertiary),
                    ),
                  ]),
                ),
              ..._buildSection(context, grp.catchUp,     icon: Icons.cake,          color: const Color(0xFFF472B6), title: 'Birthdays Today',             isBirthday: true, liveDot: false),
              ..._buildSection(context, grp.onlineNearby, icon: Icons.wifi_tethering, color: const Color(0xFF22C55E), title: 'Online Nearby',               isBirthday: false, liveDot: true),
              ..._buildSection(context, grp.bestMatches,  icon: Icons.stars,          color: const Color(0xFFFF6B6B), title: 'Best Matches',                isBirthday: false, liveDot: false),
              ..._buildSection(context, grp.sharedVibes,  icon: Icons.favorite,       color: const Color(0xFF4ECDC4), title: 'Similar Vibes',               isBirthday: false, liveDot: false),
              ..._buildSection(context, grp.sameAge,      icon: Icons.group,          color: const Color(0xFF45B7D1), title: 'Your Age Group',              isBirthday: false, liveDot: false),
              ..._buildSection(context, grp.nearby,       icon: Icons.near_me,        color: const Color(0xFF96CEB4), title: 'Close By',                    isBirthday: false, liveDot: false),
              ..._buildSection(context, grp.others,       icon: Icons.explore,        color: const Color(0xFF9B59B6), title: 'Discover',                    isBirthday: false, liveDot: false,
                  onViewAll: grp.others.isNotEmpty ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DiscoverAllScreen(users: grp.others, me: _me),
                  )) : null),
        ],
      ),
    );
  }
}

// ─── Section block ────────────────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final bool liveDot;
  final List<Widget> children;
  final bool wide;
  final bool single;
  final VoidCallback? onViewAll;

  const _SectionBlock({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.liveDot,
    required this.children,
    this.wide = false,
    this.single = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardWidth = (screenW - 36) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header (matches RN sectionHeader padding) ──────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 10),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ),
            if (liveDot) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFF052e16).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22C55E),
                          letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(width: 4),
            ],
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('View All',
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                  ]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1A1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary)),
              ),
          ]),
        ),

        // ── Card list ──────────────────────────────────────────────────────
        if (wide)
          // Birthday wide cards: intrinsic height, padded
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: children.first,
          )
        else if (single)
          // Single non-wide card: constrain height + width like the list does
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 16),
            child: SizedBox(
              height: 260,
              width: cardWidth,
              child: children.first,
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, right: 16),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: children.length,
              itemBuilder: (_, i) => SizedBox(
                width: cardWidth,
                child: children[i],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── User card ────────────────────────────────────────────────────────────────

class NearbyUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isBirthday;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>)? onSayHi;

  const NearbyUserCard({super.key, required this.user, required this.onTap, this.onSayHi, this.isBirthday = false});

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? user['username'] ?? 'Unknown') as String;
    final pic = user['profile_pic'] as String?;
    final bio = user['bio'] as String?;
    final age = _calcAge(user['birthday']);
    final gender = (user['gender'] as String?)?.toLowerCase();
    final dist = _fmtDist(user['distance']);
    final city = user['city'] as String?;
    final isOnline = user['is_online'] == true;
    final allInterests = _parseArr(user['interests']).map((e) => e.toString()).toList();
    final displayTags = allInterests.take(2).toList();
    final extraCount = allInterests.length > 2 ? allInterests.length - 2 : 0;
    final ci = (user['_ci'] as List?)?.cast<String>() ?? [];
    final pct = (user['_pct'] as double?) ?? 0;
    final bdColor =
        gender == 'male' ? const Color(0xFF3591F9) : const Color(0xFFF472B6);
    final isActiveToday = user['_isActiveToday'] == true;

    return GestureDetector(
      onTap: () => onTap(user),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBirthday ? bdColor : const Color(0xFF1F2937),
            width: isBirthday ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: isBirthday
            ? _WideCardBody(
                name: name,
                pic: pic,
                bio: bio,
                age: age,
                gender: gender,
                dist: dist,
                city: city,
                isOnline: isOnline,
                interests: displayTags,
                ci: ci,
                pct: pct,
                isBirthday: true,
                bdColor: bdColor,
                onTap: () => (onSayHi ?? onTap)(user))
            : Stack(
                children: [
                  // Card body
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Birthday banner
                      if (isBirthday)
                        Container(
                          color: bdColor,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          child: const Text('🎂 Birthday Today!',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      // Avatar — marginTop: 16
                      Padding(
                        padding: EdgeInsets.only(
                            top: isBirthday ? 8 : 16),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.border,
                              backgroundImage: pic != null
                                  ? CachedNetworkImageProvider(pic)
                                  : null,
                              child: pic == null
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          color: AppColors.text,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w600))
                                  : null,
                            ),
                            if (isOnline)
                              Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFF111827),
                                              width: 2))))
                            else if (isActiveToday)
                              Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFF111827),
                                              width: 2)))),
                          ],
                        ),
                      ),
                      // Content: paddingH:12 paddingTop:8 paddingBottom:12
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Name + gender badge
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                        child: Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Outfit',
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.text))),
                                    if (age != null &&
                                        gender != null &&
                                        (gender == 'male' || gender == 'female')) ...[
                                      const SizedBox(width: 4),
                                      _GenderBadge(gender: gender, age: age),
                                    ],
                                  ]),
                              // Bio
                              if (bio != null && bio.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(bio,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                          color: AppColors.textTertiary,
                                          height: 1.4)),
                                ),
                              // Distance · city
                              if (dist.isNotEmpty || city != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      [dist, city]
                                          .where((e) => e != null && (e as String).isNotEmpty)
                                          .cast<String>()
                                          .join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Outfit',
                                          color: AppColors.textTertiary)),
                                ),
                              // Interest tags + "+N"
                              if (!isBirthday && displayTags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...displayTags.map((tag) {
                                      final isShared = ci.any((c) =>
                                          c.toLowerCase() == tag.toLowerCase());
                                      return Flexible(
                                        fit: FlexFit.loose,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isShared
                                                ? const Color(0xFF042F2E)
                                                : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(_shortenLabel(tag),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontFamily: 'Outfit',
                                                  fontWeight: FontWeight.w500,
                                                  color: isShared
                                                      ? const Color(0xFF4ECDC4)
                                                      : AppColors.textTertiary)),
                                        ),
                                      );
                                    }),
                                    if (extraCount > 0)
                                      Text('+$extraCount',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textTertiary)),
                                  ],
                                ),
                              ],
                              const Spacer(),
                              // Say Hi button
                              GestureDetector(
                                onTap: () => (onSayHi ?? onTap)(user),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppColors.primary, width: 1.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Say Hi',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Match % badge — absolutely positioned top-right (like RN)
                  if (!isBirthday && pct >= 40)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pct >= 70
                              ? const Color(0x60065F46)
                              : const Color(0x5092400E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${pct.round()}%',
                            style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                color: pct >= 70
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFCD34D))),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WideCardBody extends StatelessWidget {
  final String name;
  final String? pic;
  final String? bio;
  final int? age;
  final String? gender;
  final String dist;
  final String? city;
  final bool isOnline;
  final List<String> interests;
  final List<String> ci;
  final double pct;
  final bool isBirthday;
  final Color bdColor;
  final VoidCallback onTap;

  const _WideCardBody(
      {required this.name,
      this.pic,
      this.bio,
      this.age,
      this.gender,
      required this.dist,
      this.city,
      required this.isOnline,
      required this.interests,
      required this.ci,
      required this.pct,
      required this.isBirthday,
      required this.bdColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isBirthday)
          Container(
            color: bdColor,
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            child: const Text('🎂 Birthday Today!',
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Stack(children: [
                CircleAvatar(
                    radius: 29,
                    backgroundColor: AppColors.border,
                    backgroundImage: pic != null
                        ? CachedNetworkImageProvider(pic!)
                        : null,
                    child: pic == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.text, fontFamily: 'Outfit'))
                        : null),
                if (isOnline)
                  Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF111827), width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Name + gender badge + match % inline
                    Row(children: [
                      Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text))),
                      if (age != null &&
                          gender != null &&
                          (gender == 'male' || gender == 'female')) ...[
                        const SizedBox(width: 4),
                        _GenderBadge(gender: gender!, age: age!),
                      ],
                      if (!isBirthday && pct >= 40) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: pct >= 70
                                ? const Color(0x60065F46)
                                : const Color(0x5092400E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${pct.round()}%',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  color: pct >= 70
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFFFCD34D))),
                        ),
                      ],
                    ]),
                    // Distance · city
                    Text(
                        [dist, city]
                            .where((e) => e != null && e!.isNotEmpty)
                            .cast<String>()
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Outfit',
                            color: AppColors.textTertiary)),
                    // Bio
                    if (bio != null && bio!.isNotEmpty)
                      Text(bio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Outfit',
                              color: AppColors.textTertiary)),
                    // First tag + "+N" (like RN wide card)
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: ci.any((c) => c.toLowerCase() ==
                                    interests[0].toLowerCase())
                                ? const Color(0xFF042F2E)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_shortenLabel(interests[0]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                  color: ci.any((c) =>
                                          c.toLowerCase() ==
                                          interests[0].toLowerCase())
                                      ? const Color(0xFF4ECDC4)
                                      : AppColors.textTertiary)),
                        ),
                        if (ci.length > 1) ...[
                          const SizedBox(width: 4),
                          Text('+${ci.length - 1}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary)),
                        ],
                      ]),
                    ],
                  ])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isBirthday ? bdColor : AppColors.primary,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(22),
                    color: isBirthday ? bdColor : Colors.transparent,
                  ),
                  child: Text(isBirthday ? 'Wish Now' : 'Say Hi',
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color:
                              isBirthday ? Colors.white : AppColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenderBadge extends StatelessWidget {
  final String gender;
  final int age;
  const _GenderBadge({required this.gender, required this.age});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'male';
    final color =
        isMale ? const Color(0xFF3591F9) : const Color(0xFFE313AB);
    final bgColor =
        isMale ? const Color(0xFF023781) : const Color(0xFF590244);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isMale ? Icons.male : Icons.female, size: 10, color: color),
        Text('$age',
            style: TextStyle(
                fontSize: 9,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String gender;
  final int minAge;
  final int maxAge;
  final void Function(String gender, int min, int max) onApply;

  const _FilterSheet(
      {required this.gender,
      required this.minAge,
      required this.maxAge,
      required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

// ─── Profile preview bottom sheet ────────────────────────────────────────────

class _ProfilePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? me;
  final VoidCallback onOpenProfile;

  const _ProfilePreviewSheet({
    required this.user,
    required this.me,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? user['username'] ?? 'Unknown') as String;
    final pic = user['profile_pic'] as String?;
    final bio = user['bio'] as String?;
    final age = _calcAge(user['birthday']);
    final gender = (user['gender'] as String?)?.toLowerCase();
    final dist = _fmtDist(user['distance']);
    final city = user['city'] as String?;
    final country = user['country'] as String?;
    final isOnline = user['is_online'] == true;
    final interests = _parseArr(user['interests']).map((e) => e.toString()).toList();
    final purpose = _parseArr(user['purpose']).map((e) => e.toString()).toList();
    final myInterests = me != null
        ? _parseArr(me!['interests']).map((e) => e.toString().toLowerCase()).toSet()
        : <String>{};
    final myPurpose = me != null
        ? _parseArr(me!['purpose']).map((e) => e.toString().toLowerCase()).toSet()
        : <String>{};
    final isMale = gender == 'male';
    final genderColor = isMale ? const Color(0xFF3591F9) : const Color(0xFFE313AB);
    final genderBg = isMale ? const Color(0xFF023781) : const Color(0xFF590244);

    final locationParts = [
      if (dist.isNotEmpty) dist,
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ];

    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: avatar + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.border,
                      backgroundImage: pic != null
                          ? CachedNetworkImageProvider(pic)
                          : null,
                      child: pic == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 28,
                                  color: AppColors.text,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600))
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.bottomSheetBg,
                                      width: 2)))),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(children: [
                        Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                        ),
                        if (age != null && gender != null && (gender == 'male' || gender == 'female')) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: genderBg, borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(isMale ? Icons.male : Icons.female, size: 13, color: genderColor),
                              Text('$age',
                                  style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: genderColor)),
                            ]),
                          ),
                        ],
                      ]),
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Outfit',
                                color: AppColors.textTertiary,
                                height: 1.4)),
                      ],
                      if (locationParts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(locationParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Outfit',
                                color: AppColors.textTertiary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Purpose section
            if (purpose.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Purpose',
                  style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: purpose.map((p) {
                  final isMatch = myPurpose.contains(p.toLowerCase());
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMatch
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isMatch ? AppColors.primary : AppColors.border,
                          width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isMatch) ...[
                        const Icon(Icons.favorite, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(p,
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: isMatch ? AppColors.primary : AppColors.textTertiary)),
                    ]),
                  );
                }).toList(),
              ),
              if (purpose.any((p) => myPurpose.contains(p.toLowerCase()))) ...[
                const SizedBox(height: 6),
                Text(
                  '${purpose.where((p) => myPurpose.contains(p.toLowerCase())).length} matching purpose',
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'Outfit', color: AppColors.primary),
                ),
              ],
            ],

            // Interests section
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Interests',
                  style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((tag) {
                  final isMatch = myInterests.contains(tag.toLowerCase());
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMatch
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isMatch ? AppColors.primary : AppColors.border,
                          width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isMatch) ...[
                        const Icon(Icons.favorite, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(tag,
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: isMatch ? AppColors.primary : AppColors.textTertiary)),
                    ]),
                  );
                }).toList(),
              ),
              if (interests.any((t) => myInterests.contains(t.toLowerCase()))) ...[
                const SizedBox(height: 6),
                Text(
                  '${interests.where((t) => myInterests.contains(t.toLowerCase())).length} matching interest${interests.where((t) => myInterests.contains(t.toLowerCase())).length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'Outfit', color: AppColors.primary),
                ),
              ],
            ],

            // Open Full Profile button
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person, color: Colors.white, size: 20),
                label: const Text('Open Full Profile',
                    style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter bottom sheet ─────────────────────────────────────────────────────

class _FilterSheetState extends State<_FilterSheet> {
  late String _gender;
  late RangeValues _ageRange;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;
    _ageRange =
        RangeValues(widget.minAge.toDouble(), widget.maxAge.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('Filter People',
                  style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ),
            const SizedBox(height: 24),
            const Text('Gender',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            Row(
                children: ['all', 'male', 'female'].map((g) {
              final isActive = _gender == g;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isActive ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5),
                      ),
                      child: Text(
                          g == 'all'
                              ? 'All'
                              : g == 'male'
                                  ? '♂ Male'
                                  : '♀ Female',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.text)),
                    ),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Age Range',
                  style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                      color: AppColors.text)),
              Text(
                  '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ]),
            RangeSlider(
              values: _ageRange,
              min: 18,
              max: 60,
              divisions: 42,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.border,
              onChanged: (v) => setState(() => _ageRange = v),
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('18',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: AppColors.textTertiary)),
                  Text('60',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: AppColors.textTertiary)),
                ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(
                    _gender,
                    _ageRange.start.round(),
                    _ageRange.end.round()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Apply',
                    style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ]),
    );
  }
}
