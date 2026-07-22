import 'package:flutter/material.dart';

class AddaChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const AddaChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final senderName = message['senderName']?.toString() ??
        message['username']?.toString() ??
        'User';
    final text = message['text']?.toString() ?? message['content']?.toString() ?? '';
    final isSystem = message['isSystem'] == true;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$senderName: ',
              style: const TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            TextSpan(
              text: text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
