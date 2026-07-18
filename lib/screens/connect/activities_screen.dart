import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/verification_badge.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

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

// ─── Screen ───────────────────────────────────────────────────────────────────

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
    final async = ref.watch(_activitiesProvider(_cityFilter));

    return async.when(
      loading: () => _buildSkeleton(),
      error: (_, __) => const Center(
        child: Text('Failed to load communities',
            style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit')),
      ),
      data: (groups) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.refresh(_activitiesProvider(_cityFilter).future),
        child: groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Column(children: [
                    const Icon(Icons.explore, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    const Text('No Public Community Yet',
                        style: TextStyle(fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text(
                      _cityFilter.isNotEmpty
                          ? 'No public community found in $_cityFilter.'
                          : 'Be the first to create a Community!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: AppColors.textTertiary),
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

  Widget _buildSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.border,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Community card ───────────────────────────────────────────────────────────

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary,
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
                                    style: const TextStyle(fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.text)),
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
                              const Icon(Icons.people, size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text('${fmtCount(memberCount)} members',
                                  style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                              if (city != null) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.location_on, size: 14, color: AppColors.textTertiary),
                                const SizedBox(width: 2),
                                Text(city, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Description
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(desc,
                      style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', color: AppColors.textSecondary, height: 1.4)),
                ],

                // Restriction badges
                if ((genderAllowed != null && genderAllowed != 'all') || minAge != null || maxAge != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (genderAllowed != null && genderAllowed != 'all')
                        _Badge(
                          icon: genderAllowed == 'male' ? Icons.male : Icons.female,
                          label: genderAllowed == 'male' ? 'Male only' : 'Female only',
                        ),
                      if (minAge != null || maxAge != null)
                        _Badge(
                          icon: Icons.cake,
                          label: minAge != null && maxAge != null
                              ? '$minAge-$maxAge yrs'
                              : minAge != null ? '$minAge+ yrs' : 'Up to $maxAge yrs',
                        ),
                    ],
                  ),
                ],

                // Footer
                const SizedBox(height: 14),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x1A808080))),
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
                                    color: AppColors.primary.withOpacity(0.082),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.188)),
                                  ),
                                  child: Text('$tag',
                                      style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.primary)),
                                )).toList(),
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: AppColors.textTertiary,
                                    backgroundImage: creatorPic != null ? CachedNetworkImageProvider(creatorPic) : null,
                                    child: creatorPic == null
                                        ? const Icon(Icons.person, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(creatorName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.textTertiary)),
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
                            color: isMember ? AppColors.primary.withOpacity(0.125) : AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMember ? 'Open' : 'Join',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: isMember ? AppColors.primary : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Paid / Pass badge
            if (isMonetized || passRequired)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1A007AFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x40007AFF)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isMonetized ? Icons.workspace_premium : Icons.lock, size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(isMonetized ? 'Paid' : 'Pass Required',
                        style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.primary)),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: AppColors.primary)),
        ]),
      );
}

class _ExploreBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ExploreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.188)),
          ),
          child: Row(children: [
            const Icon(Icons.explore, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Explore more communities',
                  style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
          ]),
        ),
      );
}
