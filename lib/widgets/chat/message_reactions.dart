import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';

// Emoji picker row for quick reactions — shown above message on long press
// Mirrors MessageReactions.jsx / EmojiReactionPicker
class QuickEmojiPicker extends StatelessWidget {
  final void Function(String emoji) onSelect;
  final VoidCallback? onMore;

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  const QuickEmojiPicker(
      {super.key, required this.onSelect, this.onMore});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._quickEmojis.map((e) => GestureDetector(
                onTap: () => onSelect(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(e,
                      style: const TextStyle(fontSize: 24)),
                ),
              )),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.border,
                  ),
                  child: Icon(Icons.add, size: 18, color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Full reaction details sheet — shows who reacted with what emoji
// Mirrors MessageReactionSheet.jsx
class MessageReactionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> reactions;
  final String? currentUserId;

  const MessageReactionSheet({
    super.key,
    required this.reactions,
    this.currentUserId,
  });

  @override
  State<MessageReactionSheet> createState() =>
      _MessageReactionSheetState();
}

class _MessageReactionSheetState extends State<MessageReactionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late List<String> _emojis;
  late Map<String, List<Map<String, dynamic>>> _grouped;

  @override
  void initState() {
    super.initState();
    _grouped = {};
    for (final r in widget.reactions) {
      final emoji = (r['emoji'] as String?) ?? '';
      if (emoji.isEmpty) continue;
      _grouped.putIfAbsent(emoji, () => []).add(r);
    }
    _emojis = ['All', ..._grouped.keys];
    _tabCtrl = TabController(length: _emojis.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabCtrl,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,

          dividerColor: Colors.transparent,
          isScrollable: true,
          tabs: _emojis.map((e) {
            final count = e == 'All'
                ? widget.reactions.length
                : _grouped[e]!.length;
            return Tab(
              child: Text(
                e == 'All' ? 'All $count' : '$e $count',
                style: const TextStyle(
                    fontFamily: 'Outfit', fontSize: 14),
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _emojis.map((e) {
              final list = e == 'All'
                  ? widget.reactions
                  : _grouped[e]!;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  final name = (r['username'] as String?) ?? 'User';
                  final avatar = r['avatar'] as String?;
                  final emoji = (r['emoji'] as String?) ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: c.border,
                      backgroundImage: avatar != null
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar == null
                          ? Text(
                              (name.isNotEmpty ? name[0] : '?')
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: c.text,
                                  fontFamily: 'Outfit'))
                          : null,
                    ),
                    title: Text(name,
                        style: TextStyle(
                            color: c.text,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500)),
                    trailing: Text(emoji,
                        style: const TextStyle(fontSize: 20)),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
