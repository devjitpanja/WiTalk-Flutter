import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

// ─── Data helpers ─────────────────────────────────────────────────────────────

List<dynamic> _parseArr(dynamic v) {
  if (v == null) return [];
  if (v is List) return v;
  return [];
}

int? _calcAge(dynamic birthday) {
  if (birthday == null) return null;
  try {
    final bd = DateTime.parse(birthday.toString());
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
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
  final myInterests = _parseArr(me['interests']).map((e) => e.toString().toLowerCase()).toSet();
  final myPurpose = _parseArr(me['purpose']).map((e) => e.toString().toLowerCase()).toSet();
  final uInterests = _parseArr(user['interests']).map((e) => e.toString().toLowerCase()).toSet();
  final uPurpose = _parseArr(user['purpose']).map((e) => e.toString().toLowerCase()).toSet();
  final commonI = myInterests.intersection(uInterests).length;
  final commonP = myPurpose.intersection(uPurpose).length;
  int pct = 0;
  if (myInterests.isNotEmpty && myPurpose.isNotEmpty) {
    pct = ((commonI / myInterests.length) * 60 + (commonP / myPurpose.length) * 40).round();
  } else if (myInterests.isNotEmpty) {
    pct = ((commonI / myInterests.length) * 100).round();
  } else if (myPurpose.isNotEmpty) {
    pct = ((commonP / myPurpose.length) * 100).round();
  }
  return pct.clamp(0, 99).toDouble();
}

List<String> _commonInterests(Map<String, dynamic> user, Map<String, dynamic>? me) {
  if (me == null) return [];
  final myInterests = _parseArr(me['interests']).map((e) => e.toString().toLowerCase()).toSet();
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
    'active chatting': 'Chatting', 'open to voice calls': 'Voice Calls',
    'open to video calls': 'Video Calls', 'random chat conversations': 'Random Chat',
    'making friends': 'Friends', 'looking for friends': 'Friends',
    'study buddy': 'Study', 'language exchange': 'Language',
  };
  return map[label.toLowerCase()] ?? label;
}

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
    required this.catchUp, required this.onlineNearby, required this.bestMatches,
    required this.sharedVibes, required this.sameAge, required this.nearby, required this.others,
  });

  bool get isEmpty => catchUp.isEmpty && onlineNearby.isEmpty && bestMatches.isEmpty &&
      sharedVibes.isEmpty && sameAge.isEmpty && nearby.isEmpty && others.isEmpty;
}

_UserGroups _groupUsers(List<dynamic> users, Map<String, dynamic>? me) {
  final catchUp = <Map<String, dynamic>>[];
  final onlineNearby = <Map<String, dynamic>>[];
  final bestMatches = <Map<String, dynamic>>[];
  final sharedVibes = <Map<String, dynamic>>[];
  final sameAge = <Map<String, dynamic>>[];
  final nearby = <Map<String, dynamic>>[];
  final others = <Map<String, dynamic>>[];

  final meAge = me != null ? _calcAge(me['birthday']) : null;
  final catchUpIds = <String>{};

  for (final raw in users) {
    final u = raw as Map<String, dynamic>;
    if (_isBirthdayToday(u['birthday'])) {
      catchUp.add(u);
      catchUpIds.add((u['uid'] ?? u['id'] ?? '').toString());
    }
  }

  final diffMs = (u) {
    final ls = u['last_seen'];
    if (ls == null) return double.infinity;
    try { return DateTime.now().difference(DateTime.parse(ls.toString())).inMilliseconds.toDouble(); } catch (_) { return double.infinity; }
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
        ? _parseArr(me['purpose']).where((p) => _parseArr(u['purpose']).any((up) => up.toString().toLowerCase() == p.toString().toLowerCase())).toList()
        : [];
    final uAge = _calcAge(u['birthday']);
    final ageDiff = (meAge != null && uAge != null) ? (meAge - uAge).abs() : 999;
    final dist = (u['distance'] as num?)?.toDouble() ?? double.infinity;

    if (isActiveToday) {
      onlineNearby.add({...u, '_pct': pct, '_ci': ci});
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
    return ((a['distance'] as num?) ?? 999).compareTo((b['distance'] as num?) ?? 999);
  });

  return _UserGroups(
    catchUp: catchUp, onlineNearby: onlineNearby.take(20).toList(),
    bestMatches: bestMatches, sharedVibes: sharedVibes, sameAge: sameAge,
    nearby: nearby, others: others,
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
  List<dynamic> _users = [];
  Map<String, dynamic>? _me;
  _UserGroups? _groups;

  // Filter state
  String _genderFilter = 'all';
  int _minAge = 18;
  int _maxAge = 60;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool force = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _permDenied = true; _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
      final uid = ref.read(authProvider).uid ?? '';
      final results = await Future.wait([
        dioClient.get('/v1/location/nearby', queryParameters: {
          'uid': uid, 'latitude': pos.latitude, 'longitude': pos.longitude, 'radius': 500,
        }),
        dioClient.get('/v1/user/$uid'),
      ]);
      final usersRes = results[0].data;
      final meRes = results[1].data;
      List users = [];
      if (usersRes is Map) users = usersRes['users'] ?? (usersRes['data'] is Map ? usersRes['data']['users'] : null) ?? [];
      Map<String, dynamic>? me;
      if (meRes is Map) {
        final u = meRes['user'] ?? meRes['data'];
        if (u is Map) me = Map<String, dynamic>.from(u);
      }
      if (mounted) {
        setState(() {
          _users = users; _me = me;
          _groups = _groupUsers(_applyFilter(users), me);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  List<dynamic> _applyFilter(List<dynamic> users) {
    return users.where((raw) {
      final u = raw as Map<String, dynamic>;
      if (_genderFilter != 'all') {
        final g = (u['gender'] as String?)?.toLowerCase() ?? '';
        if (g != _genderFilter) return false;
      }
      final age = _calcAge(u['birthday']);
      if (age != null && (age < _minAge || age > _maxAge)) return false;
      return true;
    }).toList();
  }

  void _applyFilters() {
    setState(() => _groups = _groupUsers(_applyFilter(_users), _me));
  }

  Future<void> _refresh() async {
    setState(() { _users = []; _groups = null; });
    await _init(force: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        gender: _genderFilter,
        minAge: _minAge,
        maxAge: _maxAge,
        onApply: (g, min, max) {
          setState(() { _genderFilter = g; _minAge = min; _maxAge = max; });
          _applyFilters();
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
          child: Container(margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), height: 160,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14))),
        ),
      );
    }

    if (_permDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('Location Permission Required',
                style: TextStyle(fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Enable location to discover people near you.',
                style: TextStyle(fontSize: 14, fontFamily: 'Outfit', color: AppColors.textTertiary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async { await Geolocator.openLocationSettings(); setState(() { _permDenied = false; _loading = true; }); _init(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Open Settings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    final grp = _groups;
    if (grp == null || grp.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary, backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Column(children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('No one nearby right now', style: TextStyle(fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
            SizedBox(height: 8),
            Text('Try expanding your search radius', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', color: AppColors.textTertiary)),
          ]),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary, backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32, top: 4),
            children: [
              if (grp.catchUp.isNotEmpty)
                _SectionBlock(
                  icon: Icons.cake, iconColor: const Color(0xFFF472B6),
                  title: 'Celebrate with them', count: grp.catchUp.length,
                  liveDot: false,
                  children: grp.catchUp.map((u) => _UserCard(user: u, isBirthday: true, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                  wide: true,
                ),
              if (grp.onlineNearby.isNotEmpty)
                _SectionBlock(
                  icon: Icons.wifi_tethering, iconColor: const Color(0xFF22C55E),
                  title: 'Active Nearby', count: grp.onlineNearby.length, liveDot: true,
                  children: grp.onlineNearby.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
              if (grp.bestMatches.isNotEmpty)
                _SectionBlock(
                  icon: Icons.star, iconColor: const Color(0xFF0A84FF),
                  title: 'Best Matches', count: grp.bestMatches.length, liveDot: false,
                  children: grp.bestMatches.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
              if (grp.sharedVibes.isNotEmpty)
                _SectionBlock(
                  icon: Icons.interests, iconColor: const Color(0xFF8B5CF6),
                  title: 'Shared Vibes', count: grp.sharedVibes.length, liveDot: false,
                  children: grp.sharedVibes.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
              if (grp.sameAge.isNotEmpty)
                _SectionBlock(
                  icon: Icons.people, iconColor: AppColors.primary,
                  title: 'Same Age Group', count: grp.sameAge.length, liveDot: false,
                  children: grp.sameAge.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
              if (grp.nearby.isNotEmpty)
                _SectionBlock(
                  icon: Icons.location_on, iconColor: const Color(0xFF0751DF),
                  title: 'Close By', count: grp.nearby.length, liveDot: false,
                  children: grp.nearby.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
              if (grp.others.isNotEmpty)
                _SectionBlock(
                  icon: Icons.explore, iconColor: AppColors.textTertiary,
                  title: 'Discover', count: grp.others.length, liveDot: false,
                  children: grp.others.map((u) => _UserCard(user: u, onTap: (u) => context.push('/user/${u['id'] ?? u['uid']}'))).toList(),
                ),
            ],
          ),
          // Filter FAB
          Positioned(
            right: 16, bottom: 16,
            child: FloatingActionButton.small(
              onPressed: _showFilterSheet,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.tune, color: Colors.white),
            ),
          ),
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

  const _SectionBlock({
    required this.icon, required this.iconColor, required this.title,
    required this.count, required this.liveDot, required this.children,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 36) / 2;
    final wideWidth = MediaQuery.of(context).size.width - 28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            if (liveDot) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('LIVE', style: TextStyle(fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFF22C55E), letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x1A1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
            ),
          ]),
        ),
        SizedBox(
          height: wide ? 90 : 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: children.length,
            itemBuilder: (_, i) => SizedBox(
              width: wide ? wideWidth : cardWidth,
              child: children[i],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── User card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isBirthday;
  final void Function(Map<String, dynamic>) onTap;

  const _UserCard({required this.user, required this.onTap, this.isBirthday = false});

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
    final interests = _parseArr(user['interests']).take(2).map((e) => e.toString()).toList();
    final ci = (user['_ci'] as List?)?.cast<String>() ?? [];
    final pct = (user['_pct'] as double?) ?? 0;
    final bdColor = gender == 'male' ? const Color(0xFF3591F9) : const Color(0xFFF472B6);

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
            ? _WideCardBody(name: name, pic: pic, bio: bio, age: age, gender: gender, dist: dist, city: city, isOnline: isOnline, interests: interests, ci: ci, pct: pct, isBirthday: true, bdColor: bdColor, onTap: () => onTap(user))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Match badge
                  if (pct >= 40)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pct >= 70 ? const Color(0x60065F46) : const Color(0x5092400E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${pct.round()}%',
                            style: TextStyle(fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700,
                                color: pct >= 70 ? const Color(0xFF4ADE80) : const Color(0xFFFCD34D))),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.border,
                        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                        child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)) : null,
                      ),
                      if (isOnline)
                        Positioned(bottom: 2, right: 2,
                            child: Container(width: 13, height: 13,
                                decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF111827), width: 2)))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text))),
                          if (age != null && gender != null && (gender == 'male' || gender == 'female')) ...[
                            const SizedBox(width: 4),
                            _GenderBadge(gender: gender, age: age),
                          ],
                        ]),
                        if (bio != null && bio.isNotEmpty)
                          Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary, height: 1.4)),
                        if (dist.isNotEmpty || city != null)
                          Text([dist, city].where((e) => e != null && (e as String).isNotEmpty).cast<String>().join(' · '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                        if (interests.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: interests.map((tag) {
                            final isShared = ci.any((c) => c.toLowerCase() == tag.toLowerCase());
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isShared ? const Color(0xFF042F2E) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_shortenLabel(tag), maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w500,
                                      color: isShared ? const Color(0xFF4ECDC4) : AppColors.textTertiary)),
                            );
                          }).toList()),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () => onTap(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary, width: 1.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Say Hi', textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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

  const _WideCardBody({required this.name, this.pic, this.bio, this.age, this.gender,
    required this.dist, this.city, required this.isOnline, required this.interests,
    required this.ci, required this.pct, required this.isBirthday, required this.bdColor, required this.onTap});

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
                style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Stack(children: [
                CircleAvatar(radius: 29, backgroundColor: AppColors.border,
                    backgroundImage: pic != null ? CachedNetworkImageProvider(pic!) : null,
                    child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.text, fontFamily: 'Outfit')) : null),
                if (isOnline)
                  Positioned(bottom: 2, right: 2,
                      child: Container(width: 13, height: 13,
                          decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF111827), width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text))),
                  if (age != null && gender != null && (gender == 'male' || gender == 'female')) ...[
                    const SizedBox(width: 4), _GenderBadge(gender: gender!, age: age!),
                  ],
                ]),
                Text([dist, city].where((e) => e != null && (e as String).isNotEmpty).cast<String>().join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                if (bio != null && bio!.isNotEmpty)
                  Text(bio!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
              ])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: isBirthday ? bdColor : AppColors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(22),
                    color: isBirthday ? bdColor : Colors.transparent,
                  ),
                  child: Text(isBirthday ? 'Wish Now' : 'Say Hi',
                      style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                          color: isBirthday ? Colors.white : AppColors.primary)),
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
    final color = isMale ? const Color(0xFF3591F9) : const Color(0xFFE313AB);
    final bgColor = isMale ? const Color(0xFF023781) : const Color(0xFF590244);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isMale ? Icons.male : Icons.female, size: 10, color: color),
        Text('$age', style: TextStyle(fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: color)),
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

  const _FilterSheet({required this.gender, required this.minAge, required this.maxAge, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _gender;
  late RangeValues _ageRange;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;
    _ageRange = RangeValues(widget.minAge.toDouble(), widget.maxAge.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(
          child: Text('Filter People', style: TextStyle(fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.text)),
        ),
        const SizedBox(height: 24),
        const Text('Gender', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.text)),
        const SizedBox(height: 12),
        Row(children: ['all', 'male', 'female'].map((g) {
          final isActive = _gender == g;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? AppColors.primary : AppColors.border, width: 1.5),
                  ),
                  child: Text(g == 'all' ? 'All' : g == 'male' ? '♂ Male' : '♀ Female',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.text)),
                ),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Age Range', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.text)),
          Text('${_ageRange.start.round()} – ${_ageRange.end.round()}',
              style: const TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
        RangeSlider(
          values: _ageRange,
          min: 18, max: 60,
          divisions: 42,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.border,
          onChanged: (v) => setState(() => _ageRange = v),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('18', style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
          Text('60', style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onApply(_gender, _ageRange.start.round(), _ageRange.end.round()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Apply', style: TextStyle(fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
