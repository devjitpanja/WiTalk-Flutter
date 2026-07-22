import 'package:flutter/material.dart';

class SoundWaveIndicator extends StatefulWidget {
  final bool isSpeaking;
  final Color color;
  final int barCount;
  final double barWidth;
  final double minHeight;
  final double maxHeight;

  const SoundWaveIndicator({
    super.key,
    this.isSpeaking = false,
    this.color = const Color(0xFF007AFF),
    this.barCount = 4,
    this.barWidth = 3,
    this.minHeight = 4,
    this.maxHeight = 14,
  });

  @override
  State<SoundWaveIndicator> createState() => _SoundWaveIndicatorState();
}

class _SoundWaveIndicatorState extends State<SoundWaveIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.barCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + i * 80),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox.shrink();

    final range = widget.maxHeight - widget.minHeight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.barCount, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) => Container(
            width: widget.barWidth,
            height: widget.minHeight + _controllers[i].value * range,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
