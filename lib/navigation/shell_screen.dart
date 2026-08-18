import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../providers/adda_provider.dart' show addaNotifierProvider;
import '../providers/chat_provider.dart';
import '../providers/missions_provider.dart';
import '../providers/nearby_online_provider.dart';
import '../widgets/audio_room/audio_room_overlay.dart';
import '../widgets/common/global_upload_progress.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

// Static const IconData to satisfy tree-shake-icons in release builds
const _kIconMenuBold   = IconData(0xe2f0, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter');

class _ShellScreenState extends ConsumerState<ShellScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _addaDotController;
  late final Animation<double> _addaDotOpacity;

  @override
  void initState() {
    super.initState();
    _addaDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _addaDotOpacity = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _addaDotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _addaDotController.dispose();
    super.dispose();
  }

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

    final unreadCount = ref.watch(totalUnreadCountProvider);
    final hasOnlineNearby = ref.watch(nearbyOnlineProvider);
    final hasUnclaimedMissions = ref.watch(hasUnclaimedMissionsProvider);

    // Adda live dot: check if there are any active rooms (not the user's own)
    final addaRooms = ref.watch(addaNotifierProvider.select((s) => s.rooms));
    final hasActiveRooms = addaRooms.isNotEmpty;

    // Drive blink animation based on active rooms + unfocused Adda tab
    final shouldBlinkAdda = hasActiveRooms && currentIndex != 2;
    if (shouldBlinkAdda) {
      if (!_addaDotController.isAnimating) {
        _addaDotController.repeat(reverse: true);
      }
    } else {
      if (_addaDotController.isAnimating) {
        _addaDotController.stop();
        _addaDotController.value = 1.0;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          const AudioRoomOverlay(),
          const GlobalUploadProgressOverlay(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
              icon: _buildHomeIcon(focused: false),
              activeIcon: _buildHomeIcon(focused: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildExploreIcon(focused: false, hasOnlineNearby: hasOnlineNearby),
              activeIcon: _buildExploreIcon(focused: true, hasOnlineNearby: hasOnlineNearby),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: _buildAddaIcon(focused: false, hasActiveRooms: hasActiveRooms, shouldBlink: shouldBlinkAdda),
              activeIcon: _buildAddaIcon(focused: true, hasActiveRooms: hasActiveRooms, shouldBlink: false),
              label: 'Adda',
            ),
            BottomNavigationBarItem(
              icon: _buildChatIcon(focused: false, unreadCount: unreadCount),
              activeIcon: _buildChatIcon(focused: true, unreadCount: unreadCount),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: _buildMenuIcon(focused: false, hasUnclaimedMissions: hasUnclaimedMissions),
              activeIcon: _buildMenuIcon(focused: true, hasUnclaimedMissions: hasUnclaimedMissions),
              label: 'Menu',
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHomeIcon({required bool focused}) {
    final color = focused
        ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;
    return SvgPicture.asset(
      focused ? 'assets/icons/home.svg' : 'assets/icons/home_stroke.svg',
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn),
    );
  }

  Widget _buildExploreIcon({required bool focused, required bool hasOnlineNearby}) {
    final color = focused
        ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          focused ? 'assets/icons/explore.svg' : 'assets/icons/explore_stroke.svg',
          width: 26,
          height: 26,
          colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn),
        ),
        if (hasOnlineNearby && !focused)
          Positioned(
            top: 0,
            right: -2,
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
    );
  }

  Widget _buildAddaIcon({required bool focused, required bool hasActiveRooms, required bool shouldBlink}) {
    final color = focused
        ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          focused ? 'assets/icons/mic.svg' : 'assets/icons/mic_stroke.svg',
          width: 26,
          height: 26,
          colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn),
        ),
        if (hasActiveRooms && !focused)
          Positioned(
            top: 0,
            right: -2,
            child: shouldBlink
                ? AnimatedBuilder(
                    animation: _addaDotOpacity,
                    builder: (_, __) => Opacity(
                      opacity: _addaDotOpacity.value,
                      child: _redDot(),
                    ),
                  )
                : _redDot(),
          ),
      ],
    );
  }

  Widget _buildChatIcon({required bool focused, required int unreadCount}) {
    final color = focused
        ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          focused ? 'assets/icons/chat.svg' : 'assets/icons/chat_stroke.svg',
          width: 26,
          height: 26,
          colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn),
        ),
        if (unreadCount > 0)
          Positioned(
            top: -2,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: const BoxDecoration(
                color: Color(0xFFD40B00),
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuIcon({required bool focused, required bool hasUnclaimedMissions}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          _kIconMenuBold,
          size: 26,
        ),
        if (hasUnclaimedMissions)
          Positioned(
            top: 0,
            right: -2,
            child: _redDot(),
          ),
      ],
    );
  }

  Widget _redDot() => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFFF3B30),
          shape: BoxShape.circle,
        ),
      );
}
