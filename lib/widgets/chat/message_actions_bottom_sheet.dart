import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';

// Mirrors MessageActionsBottomSheet.jsx
// Shows a bottom sheet with actions for a selected message

enum MessageAction {
  reply,
  edit,
  copy,
  delete,
  deleteForEveryone,
  pin,
  unpin,
  forward,
  translate,
  react,
  info,
}

class MessageActionsBottomSheet extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final bool isAdmin; // for group chats
  final bool isPinned;
  final bool canDeleteForEveryone;
  final void Function(MessageAction) onAction;

  const MessageActionsBottomSheet({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.isAdmin = false,
    this.isPinned = false,
    this.canDeleteForEveryone = false,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isText = message.messageType == 'text' ||
        message.messageType.isEmpty;

    final actions = <_ActionItem>[
      _ActionItem(
        action: MessageAction.reply,
        icon: Icons.reply,
        label: 'Reply',
      ),
      if (isText && isMyMessage)
        _ActionItem(
          action: MessageAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edit',
        ),
      if (isText)
        _ActionItem(
          action: MessageAction.copy,
          icon: Icons.copy,
          label: 'Copy',
        ),
      if (isPinned)
        _ActionItem(
          action: MessageAction.unpin,
          icon: Icons.push_pin_outlined,
          label: 'Unpin',
        )
      else
        _ActionItem(
          action: MessageAction.pin,
          icon: Icons.push_pin,
          label: 'Pin',
        ),
      _ActionItem(
        action: MessageAction.forward,
        icon: Icons.forward,
        label: 'Forward',
      ),
      _ActionItem(
        action: MessageAction.translate,
        icon: Icons.translate,
        label: 'Translate',
      ),
      if (isMyMessage)
        _ActionItem(
          action: MessageAction.delete,
          icon: Icons.delete_outline,
          label: 'Delete for me',
          isDestructive: true,
        ),
      if (isMyMessage && canDeleteForEveryone)
        _ActionItem(
          action: MessageAction.deleteForEveryone,
          icon: Icons.delete_forever,
          label: 'Delete for everyone',
          isDestructive: true,
        ),
      if (!isMyMessage && isAdmin)
        _ActionItem(
          action: MessageAction.deleteForEveryone,
          icon: Icons.delete_forever,
          label: 'Delete for everyone',
          isDestructive: true,
        ),
    ];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          // Message preview
          _MessagePreview(message: message, c: c),
          Divider(height: 1, color: c.border),
          // Actions grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 1,
            padding: const EdgeInsets.all(8),
            children: actions.map((item) {
              return _ActionButton(
                item: item,
                c: c,
                onTap: () {
                  Navigator.pop(context);
                  if (item.action == MessageAction.copy) {
                    Clipboard.setData(
                        ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1)),
                    );
                    return;
                  }
                  onAction(item.action);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final MessageAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ActionItem({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });
}

class _MessagePreview extends StatelessWidget {
  final ChatMessage message;
  final ThemeColors c;

  const _MessagePreview({required this.message, required this.c});

  @override
  Widget build(BuildContext context) {
    String preview;
    switch (message.messageType) {
      case 'image':
        preview = '🌄 Photo';
        break;
      case 'video':
        preview = '🎥 Video';
        break;
      case 'voice':
        preview = '🎤 Voice Message';
        break;
      case 'audio':
        preview = '🎵 Audio';
        break;
      case 'poll':
        preview = '📊 Poll';
        break;
      default:
        preview = message.content;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'Outfit',
                color: c.textSecondary),
          ),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _ActionItem item;
  final ThemeColors c;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.item, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        item.isDestructive ? c.error : c.text;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isDestructive
                  ? c.error.withOpacity(0.1)
                  : c.background,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, fontFamily: 'Outfit', color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
