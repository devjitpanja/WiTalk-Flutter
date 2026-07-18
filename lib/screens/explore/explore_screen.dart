import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

final _peopleSuggestionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/followers/suggestions', queryParameters: {'limit': 10});
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    if (payload is Map) return (payload['suggestions'] as List?) ?? [];
    if (payload is List) return payload;
  }
  return [];
});

final _popularHashtagsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/hashtags/popular', queryParameters: {'limit': 15});
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    if (payload is Map) return (payload['hashtags'] as List?) ?? [];
    if (payload is List) return payload;
  }
  return [];
});

final _publicGroupsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/groups/public/list', queryParameters: {'userId': uid, 'limit': 10, 'offset': 0});
  final data = res.data;
  if (data is Map && data['success'] == true) {
    final payload = data['data'];
    if (payload is List) return payload;
    if (payload is Map) return (payload['groups'] as List?) ?? [];
  }
  return [];
});

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(_peopleSuggestionsProvider);
    final hashtagsAsync = ref.watch(_popularHashtagsProvider);
    final groupsAsync = ref.watch(_publicGroupsProvider);

    final isLoading = peopleAsync.isLoading && hashtagsAsync.isLoading && groupsAsync.isLoading;

    void refresh() {
      ref.invalidate(_peopleSuggestionsProvider);
      ref.invalidate(_popularHashtagsProvider);
      ref.invalidate(_publicGroupsProvider);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [
          const Expanded(child: Text('Explore', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit'))),
          IconButton(icon: const Icon(Icons.search, color: Colors.white, size: 26), onPressed: () => context.push('/search')),
        ])),
        Expanded(child: isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              color: AppColors.primaryButton, backgroundColor: AppColors.surface,
              onRefresh: () async => refresh(),
              child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (peopleAsync.hasValue && (peopleAsync.value ?? []).isNotEmpty)
                    _section('People You May Know', peopleAsync.value!.map((e) => _PersonCard(person: e as Map<String, dynamic>)).toList()),
                  if (hashtagsAsync.hasValue && (hashtagsAsync.value ?? []).isNotEmpty)
                    _section('Trending Topics', hashtagsAsync.value!.map((t) => _TopicChip(topic: t)).toList()),
                  if (groupsAsync.hasValue && (groupsAsync.value ?? []).isNotEmpty)
                    _section('Communities', groupsAsync.value!.map((c) => _CommunityCard(community: c as Map<String, dynamic>)).toList()),
                ])),
            ),
        ),
      ])),
    );
  }

  Widget _section(String title, List<Widget> items) => items.isEmpty ? const SizedBox() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit'))),
    ...items,
    const SizedBox(height: 8),
  ]);

  Widget _buildSkeleton() => ListView.builder(itemCount: 5, itemBuilder: (_, __) => Shimmer.fromColors(baseColor: AppColors.surface, highlightColor: AppColors.border,
    child: Container(margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), height: 80, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)))));
}

class _PersonCard extends StatelessWidget {
  final Map<String, dynamic> person;
  const _PersonCard({required this.person});
  @override
  Widget build(BuildContext context) {
    final name = (person['name'] ?? person['username'] ?? '') as String;
    final username = person['username'] as String?;
    final pic = person['profile_pic'] as String?;
    final id = (person['suggested_id'] ?? person['id'] ?? '').toString();
    final followsMe = person['they_follow_me'] == true;
    return ListTile(contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      subtitle: username != null ? Text('@$username', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)) : null,
      trailing: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(followsMe ? 'Follow back' : 'Follow', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600))),
      onTap: () => context.push('/user/$id'),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final dynamic topic;
  const _TopicChip({required this.topic});
  @override
  Widget build(BuildContext context) {
    final tag = topic is Map ? (topic['hashtag'] ?? topic['name'] ?? '') : topic.toString();
    final usageCount = topic is Map ? topic['usage_count'] : null;
    return GestureDetector(
      onTap: () => context.push('/search-result?q=${Uri.encodeComponent(tag)}'),
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.trending_up, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#$tag', style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            if (usageCount != null) Text('$usageCount posts', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
          ])),
        ])),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Map<String, dynamic> community;
  const _CommunityCard({required this.community});
  @override
  Widget build(BuildContext context) {
    final name = community['name'] ?? '';
    final pic = community['image'] ?? community['profile_pic'];
    final id = community['id'] ?? '';
    final members = community['member_count'] ?? 0;
    return ListTile(contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      subtitle: Text('$members members', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
      onTap: () => context.push('/community-info/$id'),
    );
  }
}
