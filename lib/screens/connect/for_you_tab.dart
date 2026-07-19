import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final _topCommunitiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/groups/public/list',
      queryParameters: {'userId': uid, 'limit': 10, 'offset': 0});
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    if (payload is List) return payload;
    if (payload is Map) return (payload['groups'] as List?) ?? [];
  }
  return [];
});

final _recommendedCommunitiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/groups/public/list',
      queryParameters: {'userId': uid, 'recommended': 1, 'limit': 20});
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    if (payload is List) return payload.take(8).toList();
    if (payload is Map) {
      final rec = payload['recommended'];
      if (rec is List) return rec.take(8).toList();
    }
  }
  return [];
});

// ─── ForYouTab ───────────────────────────────────────────────────────────────

class ForYouTab extends ConsumerStatefulWidget {
  final void Function(int) onSwitchTab;
  const ForYouTab({super.key, required this.onSwitchTab});

  @override
  ConsumerState<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<ForYouTab> {
  bool _locationGranted = false;
  List<dynamic> _nearbyPeople = [];
  List<dynamic> _nearbyCommunities = [];
  bool _peopleLoading = true;
  bool _nearbyCommLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation({bool force = false}) async {
    try {
      final granted = force
          ? await locationService.requestPermission()
          : await locationService.checkPermission();
      if (!mounted) return;
      setState(() => _locationGranted = granted);
      if (!granted) {
        setState(() { _peopleLoading = false; _nearbyCommLoading = false; });
        return;
      }
      // Cache-first: serve immediately, background refresh handled inside getLocation
      final loc = await locationService.getLocation(forceRefresh: force);
      if (!mounted) return;
      await Future.wait([_fetchNearbyPeople(loc), _fetchNearbyCommunities(loc)]);
    } catch (_) {
      if (mounted) setState(() { _peopleLoading = false; _nearbyCommLoading = false; });
    }
  }

  Future<void> _fetchNearbyPeople(CachedLocation loc) async {
    try {
      final uid = ref.read(authProvider).uid ?? '';
      final res = await dioClient.get('/v1/location/nearby', queryParameters: {
        'uid': uid, 'latitude': loc.latitude, 'longitude': loc.longitude, 'radius': 500,
      });
      final data = res.data;
      List users = [];
      if (data is Map) {
        users = data['users'] ?? (data['data'] is Map ? data['data']['users'] : null) ?? [];
      }
      users.sort((a, b) => ((a['distance'] ?? 999) as num).compareTo((b['distance'] ?? 999) as num));
      if (mounted) setState(() { _nearbyPeople = users.take(6).toList(); _peopleLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _peopleLoading = false);
    }
  }

  Future<void> _fetchNearbyCommunities(CachedLocation loc) async {
    try {
      final uid = ref.read(authProvider).uid ?? '';
      final res = await dioClient.get('/v1/groups/public/nearby', queryParameters: {
        'userId': uid, 'latitude': loc.latitude, 'longitude': loc.longitude, 'limit': 20,
      });
      final data = res.data;
      if (data is Map && data['success'] == true) {
        final payload = data['data'];
        if (payload is List && mounted) setState(() { _nearbyCommunities = payload; _nearbyCommLoading = false; return; });
      }
      if (mounted) setState(() => _nearbyCommLoading = false);
    } catch (_) {
      if (mounted) setState(() => _nearbyCommLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(_topCommunitiesProvider);
    ref.invalidate(_recommendedCommunitiesProvider);
    setState(() { _peopleLoading = true; _nearbyCommLoading = true; _nearbyPeople = []; _nearbyCommunities = []; });
    await _initLocation(force: true);
  }

  String _formatCount(dynamic n) {
    final val = (n as num?)?.toInt() ?? 0;
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    return '$val';
  }

  String _formatDist(dynamic d) {
    final val = (d as num?)?.toDouble() ?? 0;
    if (val < 1) return '${(val * 1000).round()}m';
    return '${val.toStringAsFixed(1)} km';
  }

  List<dynamic> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) return tags;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final topAsync = ref.watch(_topCommunitiesProvider);
    final recAsync = ref.watch(_recommendedCommunitiesProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Communities ──
            _Section(
              emoji: '🔥',
              title: 'Top Communities',
              subtitle: 'Join what people love right now',
              onSeeAll: () => widget.onSwitchTab(1),
              child: topAsync.when(
                loading: () => _HorizSkeleton(count: 5, itemWidth: 82, itemHeight: 128),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? const _EmptyText('No communities found')
                    : SizedBox(
                        height: 128,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemCount: list.length.clamp(0, 8),
                          itemBuilder: (context, i) {
                            final g = list[i] as Map<String, dynamic>;
                            return _CommunityIconCard(
                              group: g,
                              formatCount: _formatCount,
                              onTap: () => _openGroup(context, g),
                            );
                          },
                        ),
                      ),
              ),
            ),

            // ── Matched for Your Interests ──
            recAsync.when(
              loading: () => _Section(
                emoji: '✨',
                title: 'Matched for Your Interests',
                subtitle: 'Communities picked just for you',
                onSeeAll: () => widget.onSwitchTab(1),
                child: _HorizSkeleton(count: 3, itemWidth: 240, itemHeight: 106),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : _Section(
                      emoji: '✨',
                      title: 'Matched for Your Interests',
                      subtitle: 'Communities picked just for you',
                      onSeeAll: () => widget.onSwitchTab(1),
                      child: SizedBox(
                        height: 106,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final g = list[i] as Map<String, dynamic>;
                            return _CommunityWideCard(
                              group: g,
                              width: 240,
                              formatCount: _formatCount,
                              parseTags: _parseTags,
                              onTap: () => _openGroup(context, g),
                            );
                          },
                        ),
                      ),
                    ),
            ),

            // ── City Communities ──
            if (_locationGranted && (_nearbyCommLoading || _nearbyCommunities.isNotEmpty))
              _Section(
                emoji: '📍',
                title: 'City Communities',
                subtitle: 'Communities you can join from your location',
                onSeeAll: () {},
                child: _nearbyCommLoading
                    ? _HorizSkeleton(count: 3, itemWidth: 260, itemHeight: 96)
                    : SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemCount: _nearbyCommunities.length,
                          itemBuilder: (context, i) {
                            final g = _nearbyCommunities[i] as Map<String, dynamic>;
                            return _CommunityWideCard(
                              group: g,
                              width: 260,
                              formatCount: _formatCount,
                              parseTags: _parseTags,
                              distKm: (g['distance_km'] as num?)?.toDouble(),
                              onTap: () => _openGroup(context, g),
                            );
                          },
                        ),
                      ),
              ),

            // ── People Near You ──
            if (_locationGranted)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                decoration: BoxDecoration(
                  color: const Color(0x0A0751DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_pin, color: Color(0xFF0751DF), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('People near you',
                                    style: TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
                                SizedBox(height: 2),
                                Text('Connect with like-minded people around you',
                                    style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => widget.onSwitchTab(2),
                            child: const Text('See all',
                                style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    if (_peopleLoading)
                      _HorizSkeleton(count: 5, itemWidth: 72, itemHeight: 96, paddingH: 12)
                    else if (_nearbyPeople.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text('No nearby people found',
                            style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                      )
                    else
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemCount: _nearbyPeople.length,
                          itemBuilder: (context, i) {
                            final p = _nearbyPeople[i] as Map<String, dynamic>;
                            final pic = p['profile_pic'] as String?;
                            final name = (p['name'] ?? p['username'] ?? 'User') as String;
                            final isOnline = p['is_online'] == true;
                            final dist = p['distance'];
                            return SizedBox(
                              width: 72,
                              child: GestureDetector(
                                onTap: () => context.push('/user/${p['id'] ?? p['user_id']}'),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 32,
                                          backgroundColor: AppColors.border,
                                          backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                                          child: pic == null
                                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                  style: const TextStyle(color: AppColors.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                                              : null,
                                        ),
                                        if (isOnline)
                                          Positioned(
                                            bottom: 2, right: 2,
                                            child: Container(
                                              width: 12, height: 12,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF34C759),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.background, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.text)),
                                    if (dist != null)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.location_on, size: 11, color: AppColors.textTertiary),
                                          const SizedBox(width: 2),
                                          Text(_formatDist(dist),
                                              style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openGroup(BuildContext context, Map<String, dynamic> group) {
    final isMember = group['is_member'] == true || group['is_member'] == 1;
    if (isMember) {
      context.push('/chat/group/${group['id']}');
    } else {
      context.push('/community-info/${group['invite_code'] ?? group['id']}');
    }
  }
}

// ─── Section wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;
  final Widget child;

  const _Section({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onSeeAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Text('See all',
                      style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(text, style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', color: AppColors.textTertiary)),
      );
}

// ─── Community icon card (70×70) ──────────────────────────────────────────────

class _CommunityIconCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String Function(dynamic) formatCount;
  final VoidCallback onTap;

  const _CommunityIconCard({required this.group, required this.formatCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pic = group['picture'] as String?;
    final name = (group['name'] ?? '') as String;
    final count = group['member_count'];

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: pic != null
                  ? CachedNetworkImage(imageUrl: pic, width: 70, height: 70, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 70, height: 70, color: AppColors.surface),
                      errorWidget: (_, __, ___) => _FallbackGroupIcon(size: 70))
                  : _FallbackGroupIcon(size: 70),
            ),
            const SizedBox(height: 6),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.text)),
            if (count != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group, size: 11, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Text(formatCount(count), style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Wide community card (recommended / nearby) ───────────────────────────────

class _CommunityWideCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final double width;
  final String Function(dynamic) formatCount;
  final List<dynamic> Function(dynamic) parseTags;
  final double? distKm;
  final VoidCallback onTap;

  const _CommunityWideCard({
    required this.group,
    required this.width,
    required this.formatCount,
    required this.parseTags,
    this.distKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pic = group['picture'] as String?;
    final name = (group['name'] ?? '') as String;
    final desc = group['description'] as String?;
    final city = group['city'] as String?;
    final tags = parseTags(group['tags']);
    final isNearby = distKm != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isNearby ? const Color(0x300751DF) : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: pic != null
                  ? CachedNetworkImage(imageUrl: pic, width: 64, height: 64, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 64, height: 64, color: AppColors.card),
                      errorWidget: (_, __, ___) => _FallbackGroupIcon(size: 64))
                  : _FallbackGroupIcon(size: 64),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary, height: 1.4)),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 3,
                    runSpacing: 0,
                    children: [
                      const Icon(Icons.group, size: 11, color: AppColors.textTertiary),
                      Text('${formatCount(group['member_count'])} members',
                          style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                      if (city != null) ...[
                        const Text('·', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        Text(city, style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                      ],
                      if (distKm != null) ...[
                        const Text('·', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        const Icon(Icons.location_on, size: 11, color: Color(0xFF0751DF)),
                        Text(
                          distKm! < 1 ? '${(distKm! * 1000).round()}m away' : '${distKm!.toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: Color(0xFF0751DF)),
                        ),
                      ],
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: tags.take(2).map((tag) => Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.094),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$tag', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.primary)),
                      )).toList(),
                    ),
                  ],
                  if (isNearby && group['location_radius_km'] != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x120751DF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.radar, size: 10, color: Color(0xFF0751DF)),
                        const SizedBox(width: 3),
                        Text('Within ${group['location_radius_km']} km',
                            style: const TextStyle(fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFF0751DF))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackGroupIcon extends StatelessWidget {
  final double size;
  const _FallbackGroupIcon({required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        color: AppColors.surface,
        child: const Icon(Icons.group, color: AppColors.textTertiary),
      );
}

// ─── Shimmer skeleton row ─────────────────────────────────────────────────────

class _HorizSkeleton extends StatelessWidget {
  final int count;
  final double itemWidth;
  final double itemHeight;
  final double paddingH;

  const _HorizSkeleton({
    required this.count,
    required this.itemWidth,
    required this.itemHeight,
    this.paddingH = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: paddingH),
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: count,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.border,
          child: Container(
            width: itemWidth,
            height: itemHeight,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
