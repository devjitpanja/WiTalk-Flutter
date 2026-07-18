import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _locationToIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/adda')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/account')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/explore'); break;
      case 2: context.go('/adda'); break;
      case 3: context.go('/chat'); break;
      case 4: context.go('/account'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _locationToIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => _onTap(context, i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.tabBarBg,
          selectedItemColor: AppColors.tabBarActive,
          unselectedItemColor: AppColors.tabBarInactive,
          selectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/home_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/home.png', size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/explore_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/explore.png', size: 24),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/mic_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/mic.png', size: 24),
              label: 'Adda',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/chat_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/chat.png', size: 24),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu, size: 27, color: AppColors.tabBarInactive),
              activeIcon: Icon(Icons.menu, size: 27, color: AppColors.tabBarActive),
              label: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  final String asset;
  final double size;
  const _TabIcon({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    color: Colors.white,
  );
}
