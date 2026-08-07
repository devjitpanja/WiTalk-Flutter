import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/nearby_online_provider.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/explore/explore_banner_carousel.dart';
import '../../widgets/common/witalk_header.dart';
import '../connect/for_you_tab.dart';
import '../connect/activities_screen.dart';
import '../connect/nearby_people_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeIndex = 0;

  static const _tabs = ['For You', 'Communities', 'Nearby People'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _activeIndex) {
        setState(() => _activeIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
    setState(() => _activeIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasOnlineNearby = ref.watch(nearbyOnlineProvider);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            const WiTalkHeader(
              title: 'Explore',
              showBorder: false,
              showNotifications: true,
            ),
            _PillTabBar(
              tabs: _tabs,
              activeIndex: _activeIndex,
              onTap: _switchTab,
              dotTabIndex: hasOnlineNearby ? 2 : null,
            ),
            if (_activeIndex == 0) const ExploreBannerCarousel(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ForYouTab(onSwitchTab: _switchTab),
                  const ActivitiesScreen(),
                  const NearbyPeopleScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  // When non-null, a red dot is shown on this tab index (only when not active)
  final int? dotTabIndex;

  const _PillTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    this.dotTabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (i) {
            final isActive = i == activeIndex;
            final showDot = dotTabIndex == i && !isActive;
            return Padding(
              padding: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive ? c.text : c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? c.text : c.border),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? c.background : c.textTertiary,
                        ),
                      ),
                    ),
                    if (showDot)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
