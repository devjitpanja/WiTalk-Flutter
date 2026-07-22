import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _videos = [];
  Map<String, Map<String, dynamic>> _progress = {}; // { videoId: { completed, played_at } }
  String? _selectedCat; // null = "All"
  bool _loading = true;
  String? _userId;
  Map<String, dynamic>? _activeVideo;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('uid');
    await _fetchData();
  }

  Future<void> _fetchData([bool isRefresh = false]) async {
    if (!isRefresh) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        dioClient.get('/v1/tutorials/categories'),
        dioClient.get('/v1/tutorials/videos${_userId != null ? '?userId=$_userId' : ''}'),
      ]);

      final catData = results[0].data;
      final vidData = results[1].data;

      final catsList = (catData != null && catData['data'] is List)
          ? List<Map<String, dynamic>>.from(catData['data'])
          : <Map<String, dynamic>>[];

      final vidsList = (vidData != null && vidData['data'] is List)
          ? List<Map<String, dynamic>>.from(vidData['data'])
          : <Map<String, dynamic>>[];

      final Map<String, Map<String, dynamic>> prog = {};
      for (var v in vidsList) {
        final id = (v['id'] ?? v['_id'])?.toString();
        if (id != null && v['played_at'] != null) {
          prog[id] = {
            'completed': v['completed'] == true,
            'played_at': v['played_at'].toString(),
          };
        }
      }

      if (mounted) {
        setState(() {
          _categories = catsList;
          _videos = vidsList;
          _progress = prog;
        });
      }
    } catch (e) {
      debugPrint('[TutorialScreen] fetchData error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _thumbUrl(String youtubeId) {
    return 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
  }

  Color _parseCategoryColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF007AFF);
    String hex = colorStr.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse('0x$hex') ?? 0xFF007AFF);
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'chat':
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'person':
      case 'person_outline':
        return Icons.person_outline;
      case 'star':
        return Icons.star_outline;
      case 'settings':
        return Icons.settings_outlined;
      case 'explore':
        return Icons.explore_outlined;
      case 'video-library':
      case 'video_library':
        return Icons.video_library_outlined;
      case 'apps':
        return Icons.apps;
      case 'play-circle-outline':
      case 'play_circle_outline':
      default:
        return Icons.play_circle_outline;
    }
  }

  void _handleVideoPress(Map<String, dynamic> video) async {
    setState(() {
      _activeVideo = video;
    });

    final videoId = (video['id'] ?? video['_id'])?.toString();

    if (_userId != null && videoId != null) {
      final isFirstPlay = !_progress.containsKey(videoId);

      // Track play start (non-blocking)
      dioClient.post('/v1/tutorials/track', data: {
        'userId': _userId,
        'videoId': videoId,
        'completed': false,
      }).then((_) {
        if (mounted) {
          setState(() {
            _progress[videoId] = {
              ...(_progress[videoId] ?? {}),
              'played_at': DateTime.now().toIso8601String(),
            };
            if (isFirstPlay) {
              _videos = _videos.map((v) {
                final vId = (v['id'] ?? v['_id'])?.toString();
                if (vId == videoId) {
                  final count = (v['play_count'] as num?)?.toInt() ?? 0;
                  return {...v, 'play_count': count + 1};
                }
                return v;
              }).toList();
            }
          });
        }
      }).catchError((_) {});
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _VideoPlayerModal(
        video: video,
        onCompleted: _handleVideoCompleted,
      ),
    );

    if (mounted) {
      setState(() {
        _activeVideo = null;
      });
    }
  }

  void _handleVideoCompleted() {
    if (_activeVideo == null || _userId == null) return;
    final videoId = (_activeVideo!['id'] ?? _activeVideo!['_id'])?.toString();
    if (videoId == null) return;

    dioClient.post('/v1/tutorials/track', data: {
      'userId': _userId,
      'videoId': videoId,
      'completed': true,
    }).then((_) {
      if (mounted) {
        setState(() {
          _progress[videoId] = {
            'completed': true,
            'played_at': DateTime.now().toIso8601String(),
          };
        });
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Derived data
    final filteredVideos = _selectedCat != null
        ? _videos.where((v) => (v['category_id'] ?? v['categoryId'])?.toString() == _selectedCat).toList()
        : _videos;

    final Map<String, Color> categoryColorMap = {};
    for (var c in _categories) {
      final cId = (c['id'] ?? c['_id'])?.toString();
      if (cId != null) {
        categoryColorMap[cId] = _parseCategoryColor(c['color']?.toString());
      }
    }

    final totalVideos = _videos.length;
    final watchedCount = _progress.length;
    final completedCount = _progress.values.where((p) => p['completed'] == true).length;
    final progressPct = totalVideos > 0 ? ((completedCount / totalVideos) * 100).round() : 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              color: colors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Icon(Icons.arrow_back, size: 22, color: colors.text),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Tutorials',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36, height: 36),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: colors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Loading tutorials…',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        CupertinoSliverRefreshControl(onRefresh: () => _fetchData(true)),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Progress Card
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? const [Color(0xFF0F1A3A), Color(0xFF152250), Color(0xFF1A2B66)]
                                        : const [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF1E88E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -12,
                                      top: -12,
                                      child: Icon(
                                        Icons.school,
                                        size: 88,
                                        color: Colors.white.withValues(alpha: 0.07),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Learn WiTalk',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 22,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$totalVideos tutorial${totalVideos != 1 ? 's' : ''} · Watch to master every feature',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 13,
                                              color: Colors.white.withValues(alpha: 0.7),
                                            ),
                                          ),
                                          if (totalVideos > 0) ...[
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Your progress',
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 12,
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                                Text(
                                                  '$progressPct%',
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 6,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(3),
                                                color: Colors.white.withValues(alpha: 0.2),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: FractionallySizedBox(
                                                  widthFactor: progressPct > 0 ? (progressPct / 100).clamp(0.0, 1.0) : 0.0,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(3),
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF34C759), Color(0xFF30D158)],
                                                        begin: Alignment.centerLeft,
                                                        end: Alignment.centerRight,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildHeroStat('$watchedCount', 'Watched'),
                                                Container(
                                                  width: 1,
                                                  height: 28,
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                ),
                                                _buildHeroStat('$completedCount', 'Completed'),
                                                Container(
                                                  width: 1,
                                                  height: 28,
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                ),
                                                _buildHeroStat('${totalVideos - completedCount}', 'Remaining'),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Category Tabs
                              if (_categories.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      // "All" tab
                                      _buildCategoryTab(
                                        id: null,
                                        name: 'All',
                                        iconData: Icons.apps,
                                        iconColor: _selectedCat == null ? Colors.white : colors.textSecondary,
                                        count: _videos.length,
                                        isSelected: _selectedCat == null,
                                        activeColor: colors.primary,
                                        isDark: isDark,
                                        colors: colors,
                                      ),
                                      ..._categories.map((cat) {
                                        final cId = (cat['id'] ?? cat['_id'])?.toString();
                                        final isSel = _selectedCat == cId;
                                        final catVids = _videos.where((v) => (v['category_id'] ?? v['categoryId'])?.toString() == cId).toList();
                                        final cColor = _parseCategoryColor(cat['color']?.toString());
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: _buildCategoryTab(
                                            id: cId,
                                            name: cat['name']?.toString() ?? '',
                                            iconData: _getCategoryIcon(cat['icon']?.toString()),
                                            iconColor: isSel ? Colors.white : cColor,
                                            count: catVids.length,
                                            isSelected: isSel,
                                            activeColor: cColor,
                                            isDark: isDark,
                                            colors: colors,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],

                              // Videos Grid / Empty state
                              if (filteredVideos.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 60, left: 32, right: 32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.video_library, size: 52, color: colors.textTertiary),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No videos yet',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                            color: colors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'New tutorials will appear here soon.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 13,
                                            height: 1.5,
                                            color: colors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.74,
                                    ),
                                    itemCount: filteredVideos.length,
                                    itemBuilder: (context, index) {
                                      final video = filteredVideos[index];
                                      final vId = (video['id'] ?? video['_id'])?.toString() ?? '';
                                      final catId = (video['category_id'] ?? video['categoryId'])?.toString();
                                      final isWatched = _progress.containsKey(vId);
                                      final isCompleted = _progress[vId]?['completed'] == true;

                                      return _VideoCard(
                                        video: video,
                                        thumbUrl: _thumbUrl(video['youtube_id']?.toString() ?? ''),
                                        categoryColor: categoryColorMap[catId],
                                        isWatched: isWatched,
                                        isCompleted: isCompleted,
                                        onPress: () => _handleVideoPress(video),
                                        colors: colors,
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 40),
                            ],
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

  Widget _buildHeroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w400,
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab({
    required String? id,
    required String name,
    required IconData iconData,
    required Color iconColor,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required ThemeColors colors,
  }) {
    final bgColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7));
    final borderColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF48484A) : colors.border);
    final textColor = isSelected ? Colors.white : colors.textSecondary;
    final badgeBg = isSelected
        ? Colors.white.withValues(alpha: 0.25)
        : (isDark ? const Color(0xFF3A3A3C) : colors.border);
    final badgeTextColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFE5E5EA) : colors.textTertiary);

    return GestureDetector(
      onTap: () => setState(() => _selectedCat = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Video Card ──────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final Map<String, dynamic> video;
  final String thumbUrl;
  final Color? categoryColor;
  final bool isWatched;
  final bool isCompleted;
  final VoidCallback onPress;
  final ThemeColors colors;

  const _VideoCard({
    required this.video,
    required this.thumbUrl,
    required this.categoryColor,
    required this.isWatched,
    required this.isCompleted,
    required this.onPress,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final title = video['title']?.toString() ?? '';
    final description = video['description']?.toString() ?? '';
    final playCount = (video['play_count'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onPress,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail wrap
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: thumbUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: colors.border),
                    errorWidget: (_, _, _) => Container(
                      color: colors.border,
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 32),
                      ),
                    ),
                  ),
                  // Play overlay
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                          child: const Icon(Icons.play_arrow, size: 22, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // Watched badge
                  if (isWatched)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? const Color(0xFF34C759) : const Color(0xFFFF9F0A),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.visibility,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.38,
                      color: colors.text,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: categoryColor ?? const Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        playCount > 0 ? '$playCount plays' : 'New',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Video Player Modal ───────────────────────────────────────────────────────

class _VideoPlayerModal extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback? onCompleted;

  const _VideoPlayerModal({
    required this.video,
    this.onCompleted,
  });

  @override
  State<_VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<_VideoPlayerModal> {
  late YoutubePlayerController _controller;
  bool _playerReady = false;
  bool _videoEnded = false;

  @override
  void initState() {
    super.initState();
    final youtubeId = widget.video['youtube_id']?.toString() ?? '';
    _controller = YoutubePlayerController(
      initialVideoId: youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: false,
        enableCaption: false,
        forceHD: false,
      ),
    )..addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (_controller.value.playerState == PlayerState.ended) {
      if (!_videoEnded && mounted) {
        setState(() => _videoEnded = true);
        widget.onCompleted?.call();
      }
    } else if (_controller.value.playerState == PlayerState.playing) {
      if (_videoEnded && mounted) {
        setState(() => _videoEnded = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    super.dispose();
  }

  String _thumbUrl(String youtubeId) {
    return 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = widget.video['title']?.toString() ?? '';
    final description = widget.video['description']?.toString() ?? '';
    final playCount = (widget.video['play_count'] as num?)?.toInt() ?? 0;
    final uniqueViewers = widget.video['unique_viewers'];
    final youtubeId = widget.video['youtube_id']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Player
            YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
            ),

            // Video info
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Completed banner
                    if (_videoEnded) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0x1F34C759),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x4D34C759)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Color(0xFF34C759)),
                            SizedBox(width: 8),
                            Text(
                              'Video completed!',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1.44,
                        color: colors.text,
                      ),
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.57,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Stats row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: colors.border),
                          bottom: BorderSide(color: colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 16, color: colors.textTertiary),
                              const SizedBox(width: 5),
                              Text(
                                '$playCount plays',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          if (uniqueViewers != null) ...[
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                Icon(Icons.people_outline, size: 16, color: colors.textTertiary),
                                const SizedBox(width: 5),
                                Text(
                                  '$uniqueViewers viewers',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Modal actions
                    Row(
                      children: [
                        if (_videoEnded) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _videoEnded = false);
                                _controller.seekTo(const Duration(seconds: 0));
                                _controller.play();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.border, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.replay, size: 18, color: colors.text),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Watch Again',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: colors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

