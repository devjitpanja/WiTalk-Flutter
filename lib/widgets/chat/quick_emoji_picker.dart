import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

// Quick emoji reaction bar — shown above the message actions sheet on long press.
// Mirrors the EmojiReactionPicker.jsx used in ChatConversation.jsx.
// Displays the 6 most common reaction emojis plus a "more" button.
class QuickEmojiPicker extends StatelessWidget {
  final void Function(String emoji) onSelect;
  final VoidCallback? onMore;

  const QuickEmojiPicker({
    super.key,
    required this.onSelect,
    this.onMore,
  });

  static const _emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._emojis.map((emoji) => _EmojiButton(
                emoji: emoji,
                onTap: () => onSelect(emoji),
              )),
          if (onMore != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onMore,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add,
                    size: 18, color: c.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
