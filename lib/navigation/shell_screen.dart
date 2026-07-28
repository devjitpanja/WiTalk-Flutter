import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
// Phosphor icon codepoints used directly to work around Flutter 3.44 final-IconData restriction


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
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          child,
          const AudioRoomOverlay(),
          const GlobalUploadProgressOverlay(),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) => _onTap(context, i),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: navTheme.selectedItemColor,
              unselectedItemColor: navTheme.unselectedItemColor,
              selectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w400),
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(IconData(0xe2c2, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  activeIcon: Icon(IconData(0xe2c2, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter'), size: 26),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(IconData(0xe1c8, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  activeIcon: Icon(IconData(0xe1c8, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter'), size: 26),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(IconData(0xe326, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  activeIcon: Icon(IconData(0xe326, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter'), size: 26),
                  label: 'Adda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(IconData(0xe16c, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  activeIcon: Icon(IconData(0xe16c, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter'), size: 26),
                  label: 'Chat',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(IconData(0xe2f0, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  activeIcon: Icon(IconData(0xe2f0, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'), size: 26),
                  label: 'Menu',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
