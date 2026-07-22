import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Rotating gradient border animation for room cards with admin tags,
/// matching RN `AnimatedTagBorder` component.
class AnimatedTagBorder extends StatefulWidget {
  final Color color;
  final Color bgColor;
  final Widget child;

  const AnimatedTagBorder({
    super.key,
    required this.color,
    required this.bgColor,
    required this.child,
  });

  @override
  State<AnimatedTagBorder> createState() => _AnimatedTagBorderState();
}

class _AnimatedTagBorderState extends State<AnimatedTagBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.color.withOpacity(0.31)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Rotating gradient background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _ctrl.value * 2 * math.pi,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            Colors.transparent,
                            Colors.transparent,
                            widget.color,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Inner content card with solid background & 2px border margin
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
