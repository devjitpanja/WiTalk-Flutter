import 'package:flutter/material.dart';

class CenterDecoration extends StatelessWidget {
  const CenterDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF007AFF).withOpacity(0.10),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.25)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.graphic_eq, color: Color(0xFF007AFF), size: 28),
    );
  }
}
