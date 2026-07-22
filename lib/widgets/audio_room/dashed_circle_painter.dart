import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter to render dashed circular borders for empty/locked seats.
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  const DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashLength = 6.0,
    this.dashGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final circumference = 2 * math.pi * radius;
    final totalDashCount = (circumference / (dashLength + dashGap)).floor();
    final adjustedGap = (circumference - (totalDashCount * dashLength)) / totalDashCount;

    double currentAngle = 0;
    for (int i = 0; i < totalDashCount; i++) {
      final sweepAngle = (dashLength / circumference) * (2 * math.pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        false,
        paint,
      );
      final gapAngle = (adjustedGap / circumference) * (2 * math.pi);
      currentAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap;
  }
}
