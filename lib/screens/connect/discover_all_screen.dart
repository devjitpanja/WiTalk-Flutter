import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import 'nearby_people_screen.dart';

const _kPageSize = 20;
const _kCardHeight = 262.0;
const _kCardGap = 10.0;
const _kHPad = 14.0;

class DiscoverAllScreen extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic>? me;

  const DiscoverAllScreen({super.key, required this.users, this.me});

  @override
  State<DiscoverAllScreen> createState() => _DiscoverAllScreenState();
}

class _DiscoverAllScreenState extends State<DiscoverAllScreen> {
  int _page = 1;
  bool _loadingMore = false;

  List<Map<String, dynamic>> get _visible =>
      widget.users.take(_page * _kPageSize).toList();

  bool get _hasMore => _visible.length < widget.users.length;

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() { _page++; _loadingMore = false; });
    });
  }

  void _showPreview(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _ProfilePreviewSheet(
        user: user,
        me: widget.me,
        onOpenProfile: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - _kHPad * 2 - _kCardGap) / 2;
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(_kHPad, 6, _kHPad, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, size: 22, color: AppColors.text),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.explore, size: 18, color: Color(0xFF9B59B6)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Discover',
                      style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${widget.users.length}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary)),
                ),
              ]),
            ),

            // ── Grid ────────────────────────────────────────────────────
            Expanded(
              child: widget.users.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 56, color: AppColors.textTertiary),
                          SizedBox(height: 12),
                          Text('No profiles to discover',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollEndNotification &&
                            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(_kHPad, 0, _kHPad, 30),
                        itemCount: (visible.length / 2).ceil() + 1,
                        itemBuilder: (context, rowIdx) {
                          // Last item = footer
                          final totalRows = (visible.length / 2).ceil();
                          if (rowIdx == totalRows) {
                            return _footer(context);
                          }
                          final a = visible[rowIdx * 2];
                          final bIdx = rowIdx * 2 + 1;
                          final b = bIdx < visible.length ? visible[bIdx] : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: _kCardGap),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: cardW,
                                  height: _kCardHeight,
                                  child: NearbyUserCard(
                                    user: a,
                                    onTap: (u) => _showPreview(context, u),
                                    onSayHi: (u) => context.push('/user/${u['id'] ?? u['uid']}'),
                                  ),
                                ),
                                const SizedBox(width: _kCardGap),
                                if (b != null)
                                  SizedBox(
                                    width: cardW,
                                    height: _kCardHeight,
                                    child: NearbyUserCard(
                                      user: b,
                                      onTap: (u) => _showPreview(context, u),
                                      onSayHi: (u) => context.push('/user/${u['id'] ?? u['uid']}'),
                                    ),
                                  )
                                else
                                  SizedBox(width: cardW),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }
    if (!_hasMore) return const SizedBox(height: 8);
    return GestureDetector(
      onTap: _loadMore,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Load More',
                style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Profile preview (reused from nearby — identical to the sheet there) ───────

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
    // Delegate to the shared helper already in nearby_people_screen.dart
    // by pushing the profile route directly on button press.
    // We rebuild the sheet inline to keep this file self-contained.
    final name = (user['name'] ?? user['username'] ?? 'Unknown') as String;
    final pic = user['profile_pic'] as String?;
    final bio = user['bio'] as String?;
    final age = nearbyCalcAge(user['birthday']);
    final gender = (user['gender'] as String?)?.toLowerCase();
    final dist = nearbyFmtDist(user['distance']);
    final city = user['city'] as String?;
    final country = user['country'] as String?;
    final isOnline = user['is_online'] == true;
    final interests = nearbyParseArr(user['interests']).map((e) => e.toString()).toList();
    final purpose = nearbyParseArr(user['purpose']).map((e) => e.toString()).toList();
    final myInterests = me != null
        ? nearbyParseArr(me!['interests']).map((e) => e.toString().toLowerCase()).toSet()
        : <String>{};
    final myPurpose = me != null
        ? nearbyParseArr(me!['purpose']).map((e) => e.toString().toLowerCase()).toSet()
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
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.border,
                    backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                    child: pic == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, color: AppColors.text,
                                fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                        : null,
                  ),
                  if (isOnline)
                    Positioned(bottom: 3, right: 3,
                        child: Container(width: 14, height: 14,
                            decoration: BoxDecoration(color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.bottomSheetBg, width: 2)))),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Row(children: [
                      Flexible(
                        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                      if (age != null && gender != null && (gender == 'male' || gender == 'female')) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: genderBg, borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(isMale ? Icons.male : Icons.female, size: 13, color: genderColor),
                            Text('$age', style: TextStyle(fontSize: 11, fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600, color: genderColor)),
                          ]),
                        ),
                      ],
                    ]),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(bio, maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit',
                              color: AppColors.textTertiary, height: 1.4)),
                    ],
                    if (locationParts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(locationParts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontFamily: 'Outfit',
                              color: AppColors.textTertiary)),
                    ],
                  ]),
                ),
              ],
            ),
            if (purpose.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Purpose', style: TextStyle(fontSize: 15, fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                  children: purpose.map((p) {
                    final isMatch = myPurpose.contains(p.toLowerCase());
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMatch ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isMatch ? AppColors.primary : AppColors.border, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isMatch) ...[
                          const Icon(Icons.favorite, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(p, style: TextStyle(fontSize: 13, fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            color: isMatch ? AppColors.primary : AppColors.textTertiary)),
                      ]),
                    );
                  }).toList()),
              if (purpose.any((p) => myPurpose.contains(p.toLowerCase()))) ...[
                const SizedBox(height: 6),
                Text(
                  '${purpose.where((p) => myPurpose.contains(p.toLowerCase())).length} matching purpose',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.primary),
                ),
              ],
            ],
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Interests', style: TextStyle(fontSize: 15, fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                  children: interests.map((tag) {
                    final isMatch = myInterests.contains(tag.toLowerCase());
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMatch ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isMatch ? AppColors.primary : AppColors.border, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isMatch) ...[
                          const Icon(Icons.favorite, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(tag, style: TextStyle(fontSize: 13, fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            color: isMatch ? AppColors.primary : AppColors.textTertiary)),
                      ]),
                    );
                  }).toList()),
              if (interests.any((t) => myInterests.contains(t.toLowerCase()))) ...[
                const SizedBox(height: 6),
                Text(
                  '${interests.where((t) => myInterests.contains(t.toLowerCase())).length} matching interest${interests.where((t) => myInterests.contains(t.toLowerCase())).length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: AppColors.primary),
                ),
              ],
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person, color: Colors.white, size: 20),
                label: const Text('Open Full Profile',
                    style: TextStyle(fontSize: 15, fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
