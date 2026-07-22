import 'package:flutter/material.dart';

/// Animated vertical sound wave bar matching RN `WaveBar`.
class WaveBar extends StatefulWidget {
  final int index;
  final Color color;
  final double height;

  const WaveBar({
    super.key,
    required this.index,
    this.color = const Color(0xFF007AFF),
    this.height = 22.0,
  });

  @override
  State<WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<WaveBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    final durationMs = 350 + widget.index * 60;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 90), () {
      if (mounted) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scaleY: _scaleAnim.value,
          child: Container(
            width: 2.5,
            height: widget.height,
            margin: const EdgeInsets.symmetric(horizontal: 1.0),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        );
      },
    );
  }
}
