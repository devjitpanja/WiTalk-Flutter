import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final double size;
  const VerificationBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified, color: const Color(0xFF0A84FF), size: size);
  }
}
