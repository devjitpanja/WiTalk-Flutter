import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/explore/explore_banner_carousel.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.text, size: 24),
                    onPressed: () => context.push('/search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.text, size: 24),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            // Pill tab bar
            _PillTabBar(
              tabs: _tabs,
              activeIndex: _activeIndex,
              onTap: _switchTab,
            ),
            // Banner carousel — only on For You tab
            if (_activeIndex == 0) const ExploreBannerCarousel(),
            // Tab content
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

  const _PillTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = i == activeIndex;
            return Padding(
              padding: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.text : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? AppColors.text : AppColors.border,
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.background : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
