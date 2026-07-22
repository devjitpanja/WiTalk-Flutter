import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/audio_room/audio_room_overlay.dart';
import '../widgets/common/global_upload_progress.dart';

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
    final theme = Theme.of(context);
    final navTheme = theme.bottomNavigationBarTheme;
    final dividerColor = theme.dividerTheme.color ?? const Color(0xFF38383A);
    return Scaffold(
      body: Stack(
        children: [
          child,
          const AudioRoomOverlay(),
          const GlobalUploadProgressOverlay(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => _onTap(context, i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: navTheme.backgroundColor,
          selectedItemColor: navTheme.selectedItemColor,
          unselectedItemColor: navTheme.unselectedItemColor,
          selectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/home_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/home.png', size: 24, active: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/explore_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/explore.png', size: 24, active: true),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/mic_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/mic.png', size: 24, active: true),
              label: 'Adda',
            ),
            BottomNavigationBarItem(
              icon: _TabIcon(asset: 'assets/icons/chat_stroke.png', size: 24),
              activeIcon: _TabIcon(asset: 'assets/icons/chat.png', size: 24, active: true),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu, size: 27),
              activeIcon: Icon(Icons.menu, size: 27),
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
  final bool active;
  const _TabIcon({required this.asset, required this.size, this.active = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final color = active
        ? (navTheme.selectedItemColor ?? Colors.white)
        : (navTheme.unselectedItemColor ?? const Color(0xFF8E8E93));
    final effectiveColor = isDark ? color : (color == const Color(0xFF000000) || color == Colors.black ? null : color);
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: effectiveColor,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
    );
  }
}
