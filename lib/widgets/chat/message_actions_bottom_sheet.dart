import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';

// Mirrors group/private-chat action menu in RN.
// Vertical list: Reply / Edit / Copy / Pin / Delete for me / Delete for everyone
// Admin-only: Mute / Ban / Kick (group only)

enum MessageAction {
  reply,
  edit,
  copy,
  delete,
  deleteForEveryone,
  pin,
  unpin,
  react,
  info,
  ban,
  kick,
  mute,
  unmute,
}

class MessageActionsBottomSheet extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final bool isAdmin;
  final bool isPinned;
  final bool canDeleteForEveryone;
  final bool isCommunity;
  // Admin moderation — pass non-null callbacks to show the option
  final VoidCallback? onBan;
  final VoidCallback? onKick;
  final bool isSenderMuted;
  final VoidCallback? onMute;
  final void Function(MessageAction) onAction;

  const MessageActionsBottomSheet({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.isAdmin = false,
    this.isPinned = false,
    this.canDeleteForEveryone = false,
    this.isCommunity = false,
    this.onBan,
    this.onKick,
    this.isSenderMuted = false,
    this.onMute,
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),
          _MessagePreview(message: message, c: c),
          Divider(height: 1, color: c.border),

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
          if (isAdmin)
            _ActionRow(
              icon: Icons.push_pin_outlined,
              label: isPinned ? 'Unpin' : 'Pin',
              c: c,
              onTap: () {
                Navigator.pop(context);
                onAction(isPinned ? MessageAction.unpin : MessageAction.pin);
              },
            ),
          // Mute/Unmute sender (admin, not own message)
          if (isAdmin && !isMyMessage && onMute != null)
            _ActionRow(
              icon: isSenderMuted ? Icons.volume_up : Icons.volume_off,
              label: isSenderMuted ? 'Unmute User' : 'Mute User',
              c: c,
              onTap: () {
                Navigator.pop(context);
                onMute!();
              },
            ),
          // Ban sender (admin, not own message)
          if (isAdmin && !isMyMessage && onBan != null)
            _ActionRow(
              icon: Icons.block,
              label: isCommunity ? 'Ban from Community' : 'Ban from Group',
              c: c,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                onBan!();
              },
            ),
          // Kick/Remove sender (admin, not own message)
          if (isAdmin && !isMyMessage && onKick != null)
            _ActionRow(
              icon: Icons.person_remove,
              label: isCommunity ? 'Remove from Community' : 'Remove from Group',
              c: c,
              isDestructive: true,
              color: const Color(0xFFF97316),
              onTap: () {
                Navigator.pop(context);
                onKick!();
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

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors c;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.c,
    required this.onTap,
    this.isDestructive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final col = color ?? (isDestructive ? c.error : c.text);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: col),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Outfit',
                color: col,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
      ),
    );
  }
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
