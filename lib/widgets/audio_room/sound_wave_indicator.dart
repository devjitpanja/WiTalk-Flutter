import 'package:flutter/material.dart';

class SoundWaveIndicator extends StatefulWidget {
  final bool isSpeaking;
  final Color color;

  const SoundWaveIndicator({
    super.key,
    this.isSpeaking = false,
    this.color = const Color(0xFF007AFF),
  });

  @override
  State<SoundWaveIndicator> createState() => _SoundWaveIndicatorState();
}

class _SoundWaveIndicatorState extends State<SoundWaveIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + i * 80),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            return Container(
              width: 3,
              height: 4 + _controllers[i].value * 12,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
