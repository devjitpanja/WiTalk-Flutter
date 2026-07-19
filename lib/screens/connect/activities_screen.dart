import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/verification_badge.dart';

final _activitiesProvider =
    FutureProvider.family.autoDispose<List<dynamic>, String>((ref, cityFilter) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final params = <String, dynamic>{'userId': uid, 'limit': 100, 'offset': 0};
  if (cityFilter.isNotEmpty) params['city'] = cityFilter;
  final res = await dioClient.get('/v1/groups/public/list', queryParameters: params);
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    List raw = [];
    if (payload is List) raw = payload;
    if (payload is Map) raw = (payload['groups'] as List?) ?? [];
    return raw.where((g) => g is Map && g['is_verified'] == 1).toList();
  }
  return [];
});

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  final String _cityFilter = '';

  String _fmtCount(dynamic n) {
    final val = (n as num?)?.toInt() ?? 0;
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    return '$val';
  }

  List<dynamic> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) return tags;
    return [];
  }

  void _openGroup(BuildContext context, Map<String, dynamic> group) {
    final isMember = group['is_member'] == true || group['is_member'] == 1;
    if (isMember) {
      context.push('/chat/group/${group['id']}');
    } else {
      context.push('/community-info/${group['invite_code'] ?? group['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(_activitiesProvider(_cityFilter));

    return async.when(
      loading: () => _buildSkeleton(c),
      error: (_, __) => Center(
        child: Text('Failed to load communities',
            style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit')),
      ),
      data: (groups) => RefreshIndicator(
        color: c.primary,
        backgroundColor: c.surface,
        onRefresh: () => ref.refresh(_activitiesProvider(_cityFilter).future),
        child: groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Column(children: [
                    Icon(Icons.explore, size: 64, color: c.textTertiary),
                    const SizedBox(height: 16),
                    Text('No Public Community Yet',
                        style: TextStyle(fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: c.text)),
                    const SizedBox(height: 8),
                    Text(
                      _cityFilter.isNotEmpty
                          ? 'No public community found in $_cityFilter.'
                          : 'Be the first to create a Community!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontFamily: 'Outfit', color: c.textTertiary),
                    ),
                  ]),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: groups.length + 1,
                itemBuilder: (context, i) {
                  if (i == groups.length) return _ExploreBanner(onTap: () => context.push('/communities'));
                  final g = groups[i] as Map<String, dynamic>;
                  return _CommunityCard(
                    group: g,
                    fmtCount: _fmtCount,
                    parseTags: _parseTags,
                    onTap: () => _openGroup(context, g),
                    onJoin: () => _openGroup(context, g),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSkeleton(ThemeColors c) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: c.cardBackground,
        highlightColor: c.border,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          height: 120,
          decoration: BoxDecoration(
            color: c.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String Function(dynamic) fmtCount;
  final List<dynamic> Function(dynamic) parseTags;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  const _CommunityCard({
    required this.group,
    required this.fmtCount,
    required this.parseTags,
    required this.onTap,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pic = group['picture'] as String?;
    final name = (group['name'] ?? '') as String;
    final desc = group['description'] as String?;
    final city = group['city'] as String?;
    final memberCount = group['member_count'];
    final isMember = group['is_member'] == true || group['is_member'] == 1;
    final isVerified = group['is_verified'] == 1;
    final tags = parseTags(group['tags']);
    final genderAllowed = group['gender_allowed'] as String?;
    final minAge = group['min_age'];
    final maxAge = group['max_age'];
    final isMonetized = group['is_monetized'] == true || group['is_monetized'] == 1;
    final passRequired = group['pass_required'] == true || group['pass_required'] == 1;
    final creatorPic = group['creator_pic'] as String?;
    final creatorName = (group['creator_name'] ?? group['creator_username'] ?? 'Unknown') as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withOpacity(0.5)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: c.primary,
                      backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                      child: pic == null
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: c.text)),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const VerificationBadge(size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people, size: 14, color: c.textTertiary),
                              const SizedBox(width: 4),
                              Text('${fmtCount(memberCount)} members',
                                  style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: c.textTertiary)),
                              if (city != null) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.location_on, size: 14, color: c.textTertiary),
                                const SizedBox(width: 2),
                                Text(city, style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: c.textTertiary)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(desc,
                      style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: c.textSecondary, height: 1.4)),
                ],

                if ((genderAllowed != null && genderAllowed != 'all') || minAge != null || maxAge != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (genderAllowed != null && genderAllowed != 'all')
                        _Badge(icon: genderAllowed == 'male' ? Icons.male : Icons.female,
                            label: genderAllowed == 'male' ? 'Male only' : 'Female only'),
                      if (minAge != null || maxAge != null)
                        _Badge(icon: Icons.cake,
                            label: minAge != null && maxAge != null
                                ? '$minAge-$maxAge yrs'
                                : minAge != null ? '$minAge+ yrs' : 'Up to $maxAge yrs'),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border.withOpacity(0.4))),
                  ),
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: tags.isNotEmpty
                            ? Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: tags.take(3).map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.primary.withOpacity(0.082),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: c.primary.withOpacity(0.188)),
                                  ),
                                  child: Text('$tag',
                                      style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: c.primary)),
                                )).toList(),
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: c.textTertiary,
                                    backgroundImage: creatorPic != null ? CachedNetworkImageProvider(creatorPic) : null,
                                    child: creatorPic == null
                                        ? const Icon(Icons.person, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(creatorName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: c.textTertiary)),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMember ? c.primary.withOpacity(0.125) : c.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMember ? 'Open' : 'Join',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: isMember ? c.primary : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isMonetized || passRequired)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.primary.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isMonetized ? Icons.workspace_premium : Icons.lock, size: 11, color: c.primary),
                    const SizedBox(width: 4),
                    Text(isMonetized ? 'Paid' : 'Pass Required',
                        style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: c.primary)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c.primary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: c.primary)),
      ]),
    );
  }
}

class _ExploreBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ExploreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.primary.withOpacity(0.188)),
        ),
        child: Row(children: [
          Icon(Icons.explore, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Explore more communities',
                style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: c.primary)),
          ),
          Icon(Icons.chevron_right, size: 20, color: c.primary),
        ]),
      ),
    );
  }
}
