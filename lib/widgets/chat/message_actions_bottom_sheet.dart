import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';

// Mirrors private-chat action menu in ChatConversation.jsx (RN).
// Vertical list: Reply / Edit / Copy / Forward / Translate / Delete for me / Delete for everyone

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
  final bool isAdmin;
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
    final isText =
        message.messageType == 'text' || message.messageType.isEmpty;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),
          // Message preview
          _MessagePreview(message: message, c: c),
          Divider(height: 1, color: c.border),

          // ── Actions — vertical list matching RN ─────────────────────
          _ActionRow(
            icon: Icons.reply,
            label: 'Reply',
            c: c,
            onTap: () {
              Navigator.pop(context);
              onAction(MessageAction.reply);
            },
          ),
          if (isText && isMyMessage)
            _ActionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              c: c,
              onTap: () {
                Navigator.pop(context);
                onAction(MessageAction.edit);
              },
            ),
          if (isText)
            _ActionRow(
              icon: Icons.copy_outlined,
              label: 'Copy',
              c: c,
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(
                    ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
          _ActionRow(
            icon: Icons.forward,
            label: 'Forward',
            c: c,
            onTap: () {
              Navigator.pop(context);
              onAction(MessageAction.forward);
            },
          ),
          _ActionRow(
            icon: Icons.translate_outlined,
            label: 'Translate',
            c: c,
            onTap: () {
              Navigator.pop(context);
              onAction(MessageAction.translate);
            },
          ),
          if (isPinned)
            _ActionRow(
              icon: Icons.push_pin_outlined,
              label: 'Unpin',
              c: c,
              onTap: () {
                Navigator.pop(context);
                onAction(MessageAction.unpin);
              },
            )
          else
            _ActionRow(
              icon: Icons.push_pin_outlined,
              label: 'Pin',
              c: c,
              onTap: () {
                Navigator.pop(context);
                onAction(MessageAction.pin);
              },
            ),
          if (isMyMessage)
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Delete for me',
              c: c,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                onAction(MessageAction.delete);
              },
            ),
          if (canDeleteForEveryone || (!isMyMessage && isAdmin))
            _ActionRow(
              icon: Icons.delete_forever_outlined,
              label: 'Delete for everyone',
              c: c,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                onAction(MessageAction.deleteForEveryone);
              },
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Single action row ─────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors c;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.c,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? c.error : c.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Outfit',
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Message preview header ────────────────────────────────────────────────────
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
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        preview,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 14,
            fontFamily: 'Outfit',
            color: c.textSecondary),
      ),
    );
  }
}
