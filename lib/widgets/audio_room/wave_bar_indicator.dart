import 'package:flutter/material.dart';

class WaveBarIndicator extends StatelessWidget {
  final int count;
  final Color color;

  const WaveBarIndicator({
    super.key,
    this.count = 5,
    this.color = const Color(0xFF007AFF),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final height = (i % 2 == 0) ? 14.0 : 8.0;
        return Container(
          width: 2.5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
