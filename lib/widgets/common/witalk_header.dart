import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';

/// Shared header used by Home, Explore, and Adda screens.
class WiTalkHeader extends StatelessWidget {
  final String title;
  final Widget? leadingAction;
  final bool showNotifications;
  final bool showBorder;
  final int unreadCount;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onAddPressed;

  const WiTalkHeader({
    super.key,
    this.title = 'WiTalk',
    this.leadingAction,
    this.showNotifications = true,
    this.showBorder = true,
    this.unreadCount = 0,
    this.onSearchPressed,
    this.onNotificationPressed,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: showBorder
            ? Border(bottom: BorderSide(color: c.border, width: 0.7))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leadingAction ??
                  _IconBtn(
                    onPressed: onAddPressed ?? () => context.push('/create-post'),
                    child: Image.asset(
                      'assets/icons/add.png',
                      width: 24,
                      height: 24,
                      color: isDark ? c.text : null,
                    ),
                  ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(
                    onPressed: onSearchPressed ?? () => context.push('/search'),
                    child: Icon(Icons.search, size: 26, color: c.text),
                  ),
                  if (showNotifications) ...[
                    _IconBtn(
                      onPressed: onNotificationPressed ?? () => context.push('/notifications'),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/icons/bell.png',
                            width: 24,
                            height: 24,
                            color: isDark ? c.text : null,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -1,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _IconBtn({this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: child,
        ),
      );
}
