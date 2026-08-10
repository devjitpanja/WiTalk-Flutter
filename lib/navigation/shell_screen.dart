import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
const _kIconHomeBold   = IconData(0xe2c2, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter');
const _kIconHomeFill   = IconData(0xe2c2, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter');
const _kIconMapBold    = IconData(0xe1c8, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter');
const _kIconMapFill    = IconData(0xe1c8, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter');
const _kIconAddaBold   = IconData(0xe326, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter');
const _kIconAddaFill   = IconData(0xe326, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter');
const _kIconChatBold   = IconData(0xe16c, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter');
const _kIconChatFill   = IconData(0xe16c, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter');
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
      extendBody: true,
      body: Stack(
        children: [
          widget.child,
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
                // ── Home ──────────────────────────────────────────────────────
                const BottomNavigationBarItem(
                  icon: Icon(_kIconHomeBold, size: 26),
                  activeIcon: Icon(_kIconHomeFill, size: 26),
                  label: 'Home',
                ),
                // ── Explore (red dot when online nearby users) ────────────────
                BottomNavigationBarItem(
                  icon: _buildExploreIcon(focused: false, hasOnlineNearby: hasOnlineNearby),
                  activeIcon: _buildExploreIcon(focused: true, hasOnlineNearby: hasOnlineNearby),
                  label: 'Explore',
                ),
                // ── Adda (blinking dot when live rooms exist) ─────────────────
                BottomNavigationBarItem(
                  icon: _buildAddaIcon(focused: false, hasActiveRooms: hasActiveRooms, shouldBlink: shouldBlinkAdda),
                  activeIcon: _buildAddaIcon(focused: true, hasActiveRooms: hasActiveRooms, shouldBlink: false),
                  label: 'Adda',
                ),
                // ── Chat (unread count badge) ──────────────────────────────────
                BottomNavigationBarItem(
                  icon: _buildChatIcon(focused: false, unreadCount: unreadCount),
                  activeIcon: _buildChatIcon(focused: true, unreadCount: unreadCount),
                  label: 'Chat',
                ),
                // ── Menu (red dot when unclaimed missions) ─────────────────────
                BottomNavigationBarItem(
                  icon: _buildMenuIcon(focused: false, hasUnclaimedMissions: hasUnclaimedMissions),
                  activeIcon: _buildMenuIcon(focused: true, hasUnclaimedMissions: hasUnclaimedMissions),
                  label: 'Menu',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreIcon({required bool focused, required bool hasOnlineNearby}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          focused ? _kIconMapFill : _kIconMapBold,
          size: 26,
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          focused ? _kIconAddaFill : _kIconAddaBold,
          size: 26,
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          focused ? _kIconChatFill : _kIconChatBold,
          size: 26,
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
