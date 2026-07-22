import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';
import '../../utils/image_utils.dart';

String _fmtPoints(num? points) {
  if (points == null || points == 0) return '0';
  if (points >= 1000000) return '${(points / 1000000).toStringAsFixed(1)}M';
  if (points >= 1000) return '${(points / 1000).toStringAsFixed(1)}K';
  return points.toString();
}

class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});

  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _rankData;
  bool _loading = true;
  String? _error;
  String? _currentUserId;

  late AnimationController _firstAnimCtrl;
  late AnimationController _secondAnimCtrl;
  late AnimationController _thirdAnimCtrl;

  late Animation<double> _firstHeightAnim;
  late Animation<double> _secondHeightAnim;
  late Animation<double> _thirdHeightAnim;

  late Animation<double> _firstOpacityAnim;
  late Animation<double> _secondOpacityAnim;
  late Animation<double> _thirdOpacityAnim;

  late Animation<double> _firstTranslateAnim;
  late Animation<double> _secondTranslateAnim;
  late Animation<double> _thirdTranslateAnim;

  bool _animsInitialized = false;

  @override
  void initState() {
    super.initState();

    _firstAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _secondAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _thirdAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animsInitialized) {
      final size = MediaQuery.of(context).size;
      _initAnimations(size);
      _animsInitialized = true;
    }
  }

  @override
  void dispose() {
    _firstAnimCtrl.dispose();
    _secondAnimCtrl.dispose();
    _thirdAnimCtrl.dispose();
    super.dispose();
  }

  void _initAnimations(Size size) {
    // Equal podium bar height for all positions
    final h = size.height * 0.08;

    _firstHeightAnim = Tween<double>(begin: 0, end: h).animate(
        CurvedAnimation(parent: _firstAnimCtrl, curve: Curves.easeOut));
    _secondHeightAnim = Tween<double>(begin: 0, end: h).animate(
        CurvedAnimation(parent: _secondAnimCtrl, curve: Curves.easeOut));
    _thirdHeightAnim = Tween<double>(begin: 0, end: h).animate(
        CurvedAnimation(parent: _thirdAnimCtrl, curve: Curves.easeOut));

    _firstOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _firstAnimCtrl, curve: Curves.easeOut));
    _secondOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _secondAnimCtrl, curve: Curves.easeOut));
    _thirdOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _thirdAnimCtrl, curve: Curves.easeOut));

    _firstTranslateAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _firstAnimCtrl, curve: Curves.easeOut));
    _secondTranslateAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _secondAnimCtrl, curve: Curves.easeOut));
    _thirdTranslateAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _thirdAnimCtrl, curve: Curves.easeOut));
  }

  void _startPodiumSequence() {
    _firstAnimCtrl.reset();
    _secondAnimCtrl.reset();
    _thirdAnimCtrl.reset();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _firstAnimCtrl.forward().then((_) {
        if (!mounted) return;
        _secondAnimCtrl.forward().then((_) {
          if (!mounted) return;
          _thirdAnimCtrl.forward();
        });
      });
    });
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) throw Exception('User not authenticated');
      _currentUserId = uid;

      final res = await dioClient.get('/v1/rank/user/$uid');
      dynamic rawData = res.data;

      Map<String, dynamic>? parsedData;
      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] != null && rawData['data'] is Map) {
          parsedData = Map<String, dynamic>.from(rawData['data'] as Map);
        } else if (rawData['myrank'] != null || rawData['rank_list'] != null) {
          parsedData = Map<String, dynamic>.from(rawData);
        } else if (rawData['statusCode'] == 200 && rawData['data'] != null) {
          parsedData = Map<String, dynamic>.from(rawData['data'] as Map);
        }
      }

      if (parsedData != null) {
        setState(() {
          _rankData = parsedData;
          _loading = false;
        });
        final list = parsedData['rank_list'] as List?;
        if (list != null && list.length >= 3) {
          _startPodiumSequence();
        }
      } else {
        throw Exception('Invalid response structure');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
          _rankData = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final size = MediaQuery.of(context).size;
    final insets = MediaQuery.of(context).padding;

    final backgroundColor = isDark ? const Color(0xFF0D1017) : Colors.white;
    const accentColor = Color(0xFF0751DF);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary =
        isDark ? const Color(0xFFEBEBF5) : const Color(0xFF666666);
    final errorColor =
        isDark ? const Color(0xFFFF453A) : const Color(0xFFF44336);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: accentColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(0, insets.top, 0, 16),
            decoration: const BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    size.width * 0.04,
                    0,
                    size.width * 0.04,
                    size.height * 0.015,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: InkWell(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: const Center(
                            child: Icon(Icons.arrow_back,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Leaderboard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: size.width * 0.055,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: InkWell(
                          onTap: () => context.push('/ranking-rules'),
                          borderRadius: BorderRadius.circular(20),
                          child: const Center(
                            child: Icon(Icons.info_outline,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Header Content: Podium or Skeleton
                if (_loading)
                  _renderSkeletonPodium(size)
                else if (_rankData != null &&
                    (_rankData!['rank_list'] as List?)?.isNotEmpty == true)
                  _renderPodium(size, isDark)
              ],
            ),
          ),

          // Main Body Below Header
          Expanded(
            child: _loading
                ? _renderSkeletonList(size, isDark, accentColor, textSecondary)
                : _error != null
                    ? _renderErrorState(
                        size, isDark, textSecondary, errorColor, accentColor)
                    : _rankData == null ||
                            (_rankData!['rank_list'] as List?)?.isEmpty == true
                        ? _renderEmptyState(
                            size, isDark, textPrimary, textSecondary, accentColor)
                        : _renderList(size, isDark, insets),
          ),
        ],
      ),
    );
  }

  Widget _renderSkeletonPodium(Size size) {
    return Container(
      height: size.height * 0.18,
      margin: EdgeInsets.only(top: size.height * 0.01),
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _renderSkeletonList(
      Size size, bool isDark, Color accentColor, Color textSecondary) {
    final backgroundColor = isDark ? const Color(0xFF0D1017) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 12),
            Text(
              'Loading rankings...',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
                fontSize: size.width * 0.04,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderErrorState(Size size, bool isDark, Color textSecondary,
      Color errorColor, Color accentColor) {
    final backgroundColor = isDark ? const Color(0xFF0D1017) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Oops! Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: size.width * 0.05,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
                fontSize: size.width * 0.04,
                color: textSecondary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _fetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 3,
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: size.width * 0.04,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderEmptyState(Size size, bool isDark, Color textPrimary,
      Color textSecondary, Color accentColor) {
    final backgroundColor = isDark ? const Color(0xFF0D1017) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No Rankings Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: size.width * 0.05,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rankings will be available once users start completing missions this month.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
                fontSize: size.width * 0.04,
                color: textSecondary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _fetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 3,
              ),
              child: Text(
                'Refresh',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: size.width * 0.04,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderPodium(Size size, bool isDark) {
    final rankList = List<Map<String, dynamic>>.from((_rankData!['rank_list']
            as List)
        .take(3)
        .map((e) => Map<String, dynamic>.from(e as Map)));

    return Container(
      margin: EdgeInsets.only(top: size.height * 0.01),
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (rankList.length >= 2)
            _renderTopUser(rankList[1], 2, size, isDark),
          if (rankList.isNotEmpty)
            _renderTopUser(rankList[0], 1, size, isDark),
          if (rankList.length >= 3)
            _renderTopUser(rankList[2], 3, size, isDark),
        ],
      ),
    );
  }

  Widget _renderTopUser(
      Map<String, dynamic> user, int position, Size size, bool isDark) {
    final isCurrentUser = user['id'].toString() == _currentUserId;

    Animation<double> heightAnim;
    Animation<double> opacityAnim;
    Animation<double> translateAnim;

    switch (position) {
      case 1:
        heightAnim = _firstHeightAnim;
        opacityAnim = _firstOpacityAnim;
        translateAnim = _firstTranslateAnim;
        break;
      case 2:
        heightAnim = _secondHeightAnim;
        opacityAnim = _secondOpacityAnim;
        translateAnim = _secondTranslateAnim;
        break;
      default:
        heightAnim = _thirdHeightAnim;
        opacityAnim = _thirdOpacityAnim;
        translateAnim = _thirdTranslateAnim;
        break;
    }

    final profilePicUrl = getProfileImageUrl(user);
    final avatarSize = size.width * 0.14;

    return Expanded(
      child: AnimatedBuilder(
        animation: Listenable.merge([heightAnim, opacityAnim, translateAnim]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, translateAnim.value),
            child: Opacity(
              opacity: opacityAnim.value.clamp(0.0, 1.0),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: size.width * 0.01),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User content above bar
                    GestureDetector(
                      onTap: isCurrentUser
                          ? null
                          : () => context.push('/user/${user['id']}'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Profile picture container
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: profilePicUrl != null &&
                                      profilePicUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: profilePicUrl,
                                      width: avatarSize,
                                      height: avatarSize,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                          width: avatarSize,
                                          height: avatarSize,
                                          color: Colors.white24),
                                      errorWidget: (context, url, error) =>
                                          _avatarFallback(user['name']?.toString(),
                                              avatarSize),
                                    )
                                  : _avatarFallback(user['name']?.toString(),
                                      avatarSize),
                            ),
                          ),
                          // User name
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              user['name']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: size.width * 0.038,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Followers / points badge
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.025,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              _fmtPoints(user['rank_points'] as num?),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: size.width * 0.033,
                                color: const Color(0xFF0751DF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Podium bar (equal height for all positions)
                    Container(
                      height: heightAnim.value,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                        border: isDark
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.2), width: 1)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$position',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: size.width * 0.06,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _avatarFallback(String? name, double size) {
    final initial =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      color: Colors.white24,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _renderList(Size size, bool isDark, EdgeInsets insets) {
    final rankList = (_rankData!['rank_list'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final topThreeUsers = rankList.take(3).toList();
    final remainingUsers = rankList.skip(3).toList();

    List<Map<String, dynamic>> listData = [];
    final currentUserInList = remainingUsers.firstWhere(
      (user) => user['id'].toString() == _currentUserId,
      orElse: () => {},
    );

    if (currentUserInList.isNotEmpty) {
      final otherUsers = remainingUsers
          .where((user) => user['id'].toString() != _currentUserId)
          .toList();
      listData = [currentUserInList, ...otherUsers];
    } else if (_rankData!['myrank'] != null) {
      final myRank = Map<String, dynamic>.from(_rankData!['myrank'] as Map);
      listData = [myRank, ...remainingUsers];
    } else {
      listData = remainingUsers;
    }

    final backgroundColor = isDark ? const Color(0xFF0D1017) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: size.height * 0.02),
        child: listData.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Only ${topThreeUsers.length} user${topThreeUsers.length > 1 ? "s" : ""} ranked this month',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                      fontSize: size.width * 0.04,
                      color: isDark
                          ? const Color(0xFFEBEBF5)
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  size.width * 0.05,
                  size.height * 0.01,
                  size.width * 0.05,
                  insets.bottom + 20 > 20 ? insets.bottom + 20 : 20,
                ),
                itemCount: listData.length,
                itemBuilder: (context, index) {
                  return _renderListItem(listData[index], size, isDark);
                },
              ),
      ),
    );
  }

  Widget _renderListItem(Map<String, dynamic> item, Size size, bool isDark) {
    final itemId = item['id']?.toString() ?? '';
    final isCurrentUser = itemId == _currentUserId;
    final rank = item['rank'];
    final isUnranked = rank == null;

    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary =
        isDark ? const Color(0xFFEBEBF5) : const Color(0xFF666666);
    const accentColor = Color(0xFF0751DF);
    final primaryColor =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

    final profilePicUrl = getProfileImageUrl(item);

    String rankText;
    if (isUnranked) {
      rankText = '--';
    } else {
      final r = rank is num ? rank.toInt() : int.tryParse(rank.toString()) ?? 0;
      rankText = r < 10 ? '0$r' : '$r';
    }

    return GestureDetector(
      onTap: isCurrentUser ? null : () => context.push('/user/$itemId'),
      child: Container(
        margin: EdgeInsets.only(bottom: size.height * 0.015),
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.02,
          horizontal: size.width * 0.04,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7))
              : (isDark ? const Color(0xFF0D1017) : Colors.white),
          borderRadius: BorderRadius.circular(isCurrentUser ? 15 : 12),
          border: isCurrentUser
              ? Border.all(
                  color: isDark ? accentColor : primaryColor,
                  width: 2,
                )
              : null,
        ),
        child: Row(
          children: [
            // Rank text
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: size.width * 0.08),
              child: Text(
                rankText,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight:
                      isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                  fontSize: size.width * 0.045,
                  color: isCurrentUser
                      ? (isDark ? primaryColor : accentColor)
                      : textSecondary,
                ),
              ),
            ),
            // Profile image
            Container(
              margin: EdgeInsets.symmetric(horizontal: size.width * 0.04),
              width: size.width * 0.125,
              height: size.width * 0.125,
              child: ClipOval(
                child: profilePicUrl != null && profilePicUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profilePicUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                            color: isDark
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFE5E5EA)),
                        errorWidget: (context, url, error) =>
                            _listAvatarFallback(item['name']?.toString(),
                                size.width * 0.125, isDark),
                      )
                    : _listAvatarFallback(
                        item['name']?.toString(), size.width * 0.125, isDark),
              ),
            ),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight:
                          isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                      fontSize: size.width * 0.04,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: size.height * 0.003),
                  Text(
                    isUnranked
                        ? 'Unranked - Complete missions to get ranked!'
                        : '${_fmtPoints(item['rank_points'] as num?)} mission points',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                      fontSize: size.width * 0.035,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // You badge
            if (isCurrentUser)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? accentColor : primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: size.width * 0.03,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _listAvatarFallback(String? name, double size, bool isDark) {
    final initial =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
