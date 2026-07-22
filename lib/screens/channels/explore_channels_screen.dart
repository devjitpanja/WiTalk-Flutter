import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ExploreChannelsScreen extends StatefulWidget {
  const ExploreChannelsScreen({super.key});

  @override
  State<ExploreChannelsScreen> createState() => _ExploreChannelsScreenState();
}

class _ExploreChannelsScreenState extends State<ExploreChannelsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _featuredChannels = [];
  List<Map<String, dynamic>> _channelsRaw = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFeatured();
    _loadSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    try {
      final res = await ChannelApi.getFeatured();
      final data = res.data;
      if (data != null && data['channels'] is List) {
        if (mounted) {
          setState(() {
            _featuredChannels = List<Map<String, dynamic>>.from(data['channels']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSearch(String query) async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await ChannelApi.getPublic(limit: 40, offset: 0, search: query);
      final data = res.data;
      if (data != null && data['channels'] is List) {
        if (mounted) {
          setState(() {
            _channelsRaw = List<Map<String, dynamic>>.from(data['channels']);
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String text) {
    setState(() {
      _searchQuery = text;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _loadSearch(text);
    });
  }

  Future<void> _handleSubscribe(Map<String, dynamic> item) async {
    final String channelId = item['id']?.toString() ?? '';
    final bool isSubscribed = (item['is_subscribed'] == 1 || item['is_subscribed'] == true);

    try {
      if (isSubscribed) {
        await ChannelApi.unsubscribe(channelId);
        _updateChannelState(channelId, 0);
      } else {
        await ChannelApi.subscribe(channelId);
        _updateChannelState(channelId, 1);
      }
    } catch (_) {}
  }

  void _updateChannelState(String channelId, int isSubscribed) {
    setState(() {
      _channelsRaw = _channelsRaw.map((c) {
        if (c['id']?.toString() == channelId) {
          final copy = Map<String, dynamic>.from(c);
          copy['is_subscribed'] = isSubscribed;
          return copy;
        }
        return c;
      }).toList();

      _featuredChannels = _featuredChannels.map((c) {
        if (c['id']?.toString() == channelId) {
          final copy = Map<String, dynamic>.from(c);
          copy['is_subscribed'] = isSubscribed;
          return copy;
        }
        return c;
      }).toList();
    });
  }

  void _openChannel(Map<String, dynamic> item) {
    final channelId = item['id']?.toString() ?? '';
    context.push('/channel/$channelId', extra: {'channel': item});
  }

  List<Map<String, dynamic>> get _regularChannels {
    if (_featuredChannels.isEmpty) return _channelsRaw;
    final featuredIds = _featuredChannels.map((c) => c['id']?.toString()).toSet();
    return _channelsRaw.where((c) => !featuredIds.contains(c['id']?.toString())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unjoinedFeatured = _featuredChannels.where((c) {
      final isSub = (c['is_subscribed'] == 1 || c['is_subscribed'] == true);
      return !isSub;
    }).toList();

    final regularList = _regularChannels;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top Header with Search Bar
            Container(
              padding: const EdgeInsets.only(left: 8, right: 16, top: 6, bottom: 6),
              color: colors.surface,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.text),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 20, color: colors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(
                                fontSize: 15,
                                fontFamily: 'Outfit',
                                color: colors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search channels...',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Outfit',
                                  color: colors.textSecondary,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              child: Icon(Icons.close, size: 20, color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _loading && regularList.isEmpty
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : CustomScrollView(
                      slivers: [
                        // Featured Channels Section
                        if (unjoinedFeatured.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.campaign, size: 18, color: colors.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Featured Channels',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.bold,
                                              color: colors.primary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: colors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Official picks',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.w600,
                                              color: colors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Channels curated by WiTalk — not communities or groups',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Outfit',
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...unjoinedFeatured.map((item) => _buildFeaturedCard(item, colors)),
                                  Divider(height: 1, color: colors.border.withOpacity(0.3)),
                                ],
                              ),
                            ),
                          ),

                        // Search Result List
                        if (regularList.isEmpty && unjoinedFeatured.isEmpty && !_loading)
                          SliverFillRemaining(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.campaign, size: 64, color: colors.textSecondary),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No channels found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.trim().isNotEmpty
                                          ? 'Try a different search term'
                                          : 'Check back later for new channels',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Outfit',
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = regularList[index];
                                return _buildChannelItem(item, colors);
                              },
                              childCount: regularList.length,
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

  Widget _buildFeaturedCard(Map<String, dynamic> item, ThemeColors colors) {
    final iconUrl = item['icon']?.toString();
    final name = item['name']?.toString() ?? 'Channel';
    final desc = item['description']?.toString();
    final isVerified = (item['is_verified'] == 1 || item['is_verified'] == true);
    final subscriberCount = (item['subscriber_count'] as num?)?.toInt() ?? 0;
    final topic = item['topic']?.toString();
    final isSubscribed = (item['is_subscribed'] == 1 || item['is_subscribed'] == true);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: colors.primary),
            Expanded(
              child: InkWell(
                onTap: () => _openChannel(item),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                              image: iconUrl != null && iconUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(iconUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: iconUrl == null || iconUrl.isEmpty
                                ? const Icon(Icons.campaign, color: Colors.white, size: 26)
                                : null,
                          ),
                          Positioned(
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'CHANNEL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 15, color: Color(0xFF0751DF)),
                                ],
                              ],
                            ),
                            if (desc != null && desc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.people, size: 12, color: colors.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  '$subscriberCount subscribers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Outfit',
                                    color: colors.textTertiary,
                                  ),
                                ),
                                if (topic != null && topic.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: colors.textTertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      topic,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Outfit',
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action Button
                      if (isSubscribed)
                        OutlinedButton(
                          onPressed: () => _openChannel(item),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(56, 32),
                          ),
                          child: Text(
                            'Open',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _handleSubscribe(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            minimumSize: const Size(56, 32),
                          ),
                          child: const Text(
                            'Subscribe',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelItem(Map<String, dynamic> item, ThemeColors colors) {
    final iconUrl = item['icon']?.toString();
    final name = item['name']?.toString() ?? 'Channel';
    final desc = item['description']?.toString();
    final isVerified = (item['is_verified'] == 1 || item['is_verified'] == true);
    final subscriberCount = (item['subscriber_count'] as num?)?.toInt() ?? 0;
    final isSubscribed = (item['is_subscribed'] == 1 || item['is_subscribed'] == true);

    return InkWell(
      onTap: () => _openChannel(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border.withOpacity(0.15))),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
                image: iconUrl != null && iconUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(iconUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: iconUrl == null || iconUrl.isEmpty
                  ? Text(
                      (name.isNotEmpty ? name[0] : 'C').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
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
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: Color(0xFF0751DF)),
                      ],
                    ],
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    '$subscriberCount subscribers',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Button
            if (isSubscribed)
              OutlinedButton(
                onPressed: () => _handleSubscribe(item),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: Text(
                  'Subscribed',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => _handleSubscribe(item),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                ),
                child: Text(
                  'Subscribe',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
