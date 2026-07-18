import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../api/dio_client.dart';
import '../../theme/app_colors.dart';

final _bannersProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final res = await dioClient.get('/v1/config/explore-banners');
    final json = res.data;
    if (json is Map && json['success'] == true) {
      return Map<String, dynamic>.from(json['data'] as Map);
    }
  } catch (_) {}
  return {};
});

class ExploreBannerCarousel extends ConsumerStatefulWidget {
  const ExploreBannerCarousel({super.key});

  @override
  ConsumerState<ExploreBannerCarousel> createState() => _ExploreBannerCarouselState();
}

class _ExploreBannerCarouselState extends ConsumerState<ExploreBannerCarousel> {
  final _pageController = PageController();
  int _activeIdx = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePress(BuildContext context, Map<String, dynamic> banner) {
    final actionType = banner['action_type'] as String?;
    final actionValue = banner['action_value'] as String?;
    if (actionType == null || actionType == 'none' || actionValue == null) return;

    if (actionType == 'open_link' || actionType == 'deep_link') {
      launchUrl(Uri.parse(actionValue), mode: LaunchMode.externalApplication);
    } else if (actionType == 'open_community') {
      context.push('/community-info/$actionValue');
    } else if (actionType == 'open_profile') {
      context.push('/user/$actionValue');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_bannersProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final settings = data['settings'] as Map? ?? {};
        final enabled = settings['enabled'] != false;
        final autoplay = settings['autoplay'] != false;
        final intervalSec = (settings['interval_sec'] as num?)?.toInt() ?? 4;
        final banners = (data['banners'] as List?) ?? [];

        if (!enabled || banners.isEmpty) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        const hMargin = 16.0;
        final carouselWidth = screenWidth - hMargin * 2;
        final bannerHeight = (carouselWidth / 4.0).roundToDouble();

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: hMargin),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: carouselWidth,
                    height: bannerHeight,
                    child: _AutoplayPageView(
                      pageController: _pageController,
                      banners: banners,
                      autoplay: autoplay,
                      intervalSec: intervalSec,
                      onPageChanged: (i) => setState(() => _activeIdx = i),
                      onPress: (b) => _handlePress(context, b as Map<String, dynamic>),
                      carouselWidth: carouselWidth,
                      bannerHeight: bannerHeight,
                    ),
                  ),
                ),
              ),
              if (banners.length > 1) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (i) {
                    final isActive = i == _activeIdx;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isActive ? 16 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.33),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 2),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AutoplayPageView extends StatefulWidget {
  final PageController pageController;
  final List banners;
  final bool autoplay;
  final int intervalSec;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<dynamic> onPress;
  final double carouselWidth;
  final double bannerHeight;

  const _AutoplayPageView({
    required this.pageController,
    required this.banners,
    required this.autoplay,
    required this.intervalSec,
    required this.onPageChanged,
    required this.onPress,
    required this.carouselWidth,
    required this.bannerHeight,
  });

  @override
  State<_AutoplayPageView> createState() => _AutoplayPageViewState();
}

class _AutoplayPageViewState extends State<_AutoplayPageView> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay && widget.banners.length > 1) {
      _ticker = Stream.periodic(Duration(seconds: widget.intervalSec), (i) => i);
      _ticker.listen((_) {
        if (!mounted) return;
        final next = ((widget.pageController.page?.round() ?? 0) + 1) % widget.banners.length;
        widget.pageController.animateToPage(next,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.banners.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, i) {
        final banner = widget.banners[i] as Map<String, dynamic>;
        final imageUrl = banner['image_url'] as String?;
        final actionType = banner['action_type'] as String?;
        final actionValue = banner['action_value'] as String?;
        final isInteractive = actionType != null && actionType != 'none' && actionValue != null;

        return GestureDetector(
          onTap: isInteractive ? () => widget.onPress(banner) : null,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: widget.carouselWidth,
                  height: widget.bannerHeight,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => Container(color: AppColors.surface),
                )
              : Container(color: AppColors.surface),
        );
      },
    );
  }
}
