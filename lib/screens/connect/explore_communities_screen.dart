import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/live_group_avatar.dart';

class ExploreCommunitiesScreen extends ConsumerStatefulWidget {
  const ExploreCommunitiesScreen({super.key});

  @override
  ConsumerState<ExploreCommunitiesScreen> createState() =>
      _ExploreCommunitiesScreenState();
}

class _ExploreCommunitiesScreenState
    extends ConsumerState<ExploreCommunitiesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGroups(isRefresh: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _fetchGroups();
    }
  }

  Future<void> _fetchGroups({bool isRefresh = false}) async {
    if (_loadingMore && !isRefresh) return;
    final uid = ref.read(authProvider).uid ?? '';
    final offset = isRefresh ? 0 : _groups.length;
    const limit = 40;

    if (isRefresh) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await dioClient.get(
        '/v1/groups/public/list',
        queryParameters: {
          'userId': uid,
          'limit': limit,
          'offset': offset,
          if (_search.isNotEmpty) 'search': _search,
        },
      );
      final raw = res.data['data'];
      List<dynamic> newItems = [];
      if (raw is List) {
        newItems = raw;
      } else if (raw is Map && raw['groups'] is List) {
        newItems = raw['groups'] as List;
      }
      // filter out verified communities
      final filtered = newItems
          .where((g) => g['is_verified'] != 1)
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        if (isRefresh || offset == 0) {
          _groups = filtered;
        } else {
          final seen = <dynamic>{..._groups.map((g) => g['id'])};
          _groups = [..._groups, ...filtered.where((g) => !seen.contains(g['id']))];
        }
        _hasMore = newItems.length >= limit;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = value;
        _groups = [];
        _hasMore = true;
      });
      _fetchGroups(isRefresh: true);
    });
  }

  void _navigate(Map<String, dynamic> group) {
    final id = group['id']?.toString() ?? '';
    final isMember = group['is_member'] == true || group['is_member'] == 1;
    if (isMember) {
      context.push('/chat/group/$id');
    } else {
      context.push('/community-info/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : _groups.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _groups.length + (_loadingMore ? 1 : 0),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemBuilder: (_, i) {
                            if (i == _groups.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _CommunityItem(
                              group: _groups[i],
                              onTap: () => _navigate(_groups[i]),
                              onJoin: () => _navigate(_groups[i]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _BackBtn(onTap: () => context.pop()),
          const SizedBox(width: 4),
          Expanded(
            child: _SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final hasSearch = _search.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No communities found',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different search term'
                  : 'Check back later for new communities',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Outfit',
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1f2e),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontFamily: 'Outfit',
              ),
              decoration: const InputDecoration(
                hintText: 'Search communities...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontFamily: 'Outfit',
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              autocorrect: false,
              textInputAction: TextInputAction.search,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isNotEmpty
                ? GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    ),
                  )
                : const SizedBox(width: 12),
          ),
        ],
      ),
    );
  }
}

class _CommunityItem extends StatelessWidget {
  const _CommunityItem({
    required this.group,
    required this.onTap,
    required this.onJoin,
  });

  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  String _formatMembers(dynamic count) {
    final n = (count as num?)?.toInt() ?? 0;
    if (n >= 1000) {
      return n % 1000 == 0
          ? '${n ~/ 1000}k'
          : '${(n / 1000.0).toStringAsFixed(1)}k';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String? ?? '';
    final picture = group['picture'] as String?;
    final description = group['description'] as String?;
    final memberCount = group['member_count'];
    final city = group['city'] as String?;
    final isLive = group['active_adda_room_id'] != null || group['is_live'] == true;
    final isMember = group['is_member'] == true || group['is_member'] == 1;
    final isVerified = group['is_verified'] == 1;
    final id = group['id']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x26808080), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(context, picture, name, isLive, id),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        color: AppColors.textSecondary,
                        height: 1.38,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatMembers(memberCount)} members',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (city != null && city.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on, size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Outfit',
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isMember ? _OpenButton(onTap: onTap) : _JoinButton(onTap: onJoin),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? picture, String name, bool isLive, String id) {
    if (isLive) {
      return LiveGroupAvatar(
        picture: picture,
        size: 52,
        primaryColor: AppColors.primary,
        onPress: () => context.push(
          '/community-adda-list/$id',
          extra: {
            'groupName': name,
            'groupPicture': picture,
          },
        ),
      );
    }
    if (picture != null && picture.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: picture,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 52,
            height: 52,
            color: AppColors.border,
          ),
          errorWidget: (_, __, ___) => _placeholderAvatar(name),
        ),
      );
    }
    return _placeholderAvatar(name);
  }

  Widget _placeholderAvatar(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.group, size: 24, color: Colors.white),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Join',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary),
        ),
        child: const Text(
          'Open',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
