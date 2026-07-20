import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';
import 'voice_message_player.dart';
import 'poll_message.dart';

// ── Message bubble — renders all message types from ChatConversation ──────────
// Mirrors the message rendering logic in ChatConversation.jsx and
// GroupChatScreen.jsx, including:
//   text, image, video, audio, voice, poll, giphy_gif, giphy_sticker,
//   shared_post, shared_topic, system, deleted

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final bool showAvatar; // for group chats
  final String? senderName; // for group chats
  final String? currentUserId; // needed for reaction highlight
  final ChatMessage? replyToMessage;
  final VoidCallback? onLongPress;
  final void Function(ChatMessage)? onReplySwipe;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onTapAvatar;
  final VoidCallback? onTapImage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.showAvatar = false,
    this.senderName,
    this.currentUserId,
    this.replyToMessage,
    this.onLongPress,
    this.onReplySwipe,
    this.onReactionTap,
    this.onTapAvatar,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (message.isSystem) {
      return _SystemMessage(message: message, c: c);
    }

    if (message.isDeleted) {
      return _DeletedMessage(
          message: message, isMyMessage: isMyMessage, c: c);
    }

    return _buildBubble(context, c);
  }

  Widget _buildBubble(BuildContext context, ThemeColors c) {
    final hasReactions = (message.reactions?.isNotEmpty ?? false);

    Widget bubble = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMyMessage
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMyMessage && showAvatar) ...[
                GestureDetector(
                  onTap: onTapAvatar,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: c.surface,
                    backgroundImage: message.senderPic != null
                        ? CachedNetworkImageProvider(message.senderPic!)
                        : null,
                    child: message.senderPic == null
                        ? Text(
                            (message.senderName.isNotEmpty
                                    ? message.senderName[0]
                                    : '?')
                                .toUpperCase(),
                            style: TextStyle(
                                color: c.text,
                                fontSize: 11,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (!isMyMessage && showAvatar) ...[
                const SizedBox(width: 40),
              ],
              if (isMyMessage) const SizedBox(width: 60),
              Flexible(
                child: GestureDetector(
                  onLongPress: onLongPress,
                  child: _BubbleContent(
                    message: message,
                    isMyMessage: isMyMessage,
                    senderName: showAvatar ? senderName : null,
                    replyToMessage: replyToMessage,
                    onTapImage: onTapImage,
                    c: c,
                  ),
                ),
              ),
              if (!isMyMessage) const SizedBox(width: 60),
            ],
          ),
          if (hasReactions)
            Padding(
              padding: EdgeInsets.only(
                left: isMyMessage ? 0 : (showAvatar ? 40 : 8),
                right: isMyMessage ? 8 : 0,
                top: 2,
                bottom: 6,
              ),
              child: _ReactionsRow(
                reactions: message.reactions!,
                isMyMessage: isMyMessage,
                currentUserId: currentUserId,
                onTap: onReactionTap,
                c: c,
              ),
            ),
        ],
      ),
    );

    if (onReplySwipe != null) {
      return _SwipeToReply(
        isMyMessage: isMyMessage,
        onReply: () => onReplySwipe!(message),
        c: c,
        child: bubble,
      );
    }
    return bubble;
  }
}

// ── Bubble Content ─────────────────────────────────────────────────────────────
class _BubbleContent extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final String? senderName;
  final ChatMessage? replyToMessage;
  final VoidCallback? onTapImage;
  final ThemeColors c;

  const _BubbleContent({
    required this.message,
    required this.isMyMessage,
    this.senderName,
    this.replyToMessage,
    this.onTapImage,
    required this.c,
  });

  Color get _bubbleColor => isMyMessage
      ? c.primary
      : c.surface;

  Color get _textColor =>
      isMyMessage ? Colors.white : c.text;

  @override
  Widget build(BuildContext context) {
    final type = message.messageType;

    switch (type) {
      case 'image':
        return _ImageBubble(
            message: message,
            isMyMessage: isMyMessage,
            onTap: onTapImage,
            c: c);
      case 'voice':
        return _VoiceBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'poll':
        return _PollBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'giphy_gif':
      case 'giphy_sticker':
        return _GiphyBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'video':
        return _VideoBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'audio':
        return _AudioBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'shared_post':
        return _SharedPostBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      default:
        return _TextBubble(
          message: message,
          isMyMessage: isMyMessage,
          senderName: senderName,
          replyToMessage: replyToMessage,
          bubbleColor: _bubbleColor,
          textColor: _textColor,
          c: c,
        );
    }
  }
}

// ── Text Bubble ────────────────────────────────────────────────────────────────
class _TextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final String? senderName;
  final ChatMessage? replyToMessage;
  final Color bubbleColor;
  final Color textColor;
  final ThemeColors c;

  const _TextBubble({
    required this.message,
    required this.isMyMessage,
    this.senderName,
    this.replyToMessage,
    required this.bubbleColor,
    required this.textColor,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 16),
        ),
        border: isMyMessage
            ? null
            : Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment:
            isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Group chat sender name
          if (senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
          // Reply preview
          if (replyToMessage != null || message.replyTo != null)
            _ReplyPreview(
              replyTo: replyToMessage,
              replyToJson: message.replyTo,
              isMyMessage: isMyMessage,
              c: c,
            ),
          // Text content
          if (message.content.isNotEmpty)
            _RichText(
                text: message.content,
                textColor: textColor,
                isMyMessage: isMyMessage,
                c: c),
          // Link preview
          if (message.linkPreview != null)
            _LinkPreviewCard(
                preview: message.linkPreview!,
                isMyMessage: isMyMessage,
                c: c),
          const SizedBox(height: 2),
          // Timestamp + status
          _TimeStatus(
              message: message, isMyMessage: isMyMessage, c: c),
        ],
      ),
    );
  }
}

// ── Rich Text with link/mention support ──────────────────────────────────────
class _RichText extends StatelessWidget {
  final String text;
  final Color textColor;
  final bool isMyMessage;
  final ThemeColors c;

  const _RichText({
    required this.text,
    required this.textColor,
    required this.isMyMessage,
    required this.c,
  });

  static final _urlRegex = RegExp(r'(https?://[^\s]+)|(@\w+)');

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontFamily: 'Outfit'),
      );
    }

    final spans = <TextSpan>[];
    int last = 0;
    for (final match in matches) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, match.start),
            style: TextStyle(color: textColor, fontFamily: 'Outfit')));
      }
      final matched = match.group(0)!;
      if (matched.startsWith('@')) {
        spans.add(TextSpan(
          text: matched,
          style: TextStyle(
            color: isMyMessage
                ? const Color(0xFF93C5FD)
                : c.primary,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
          recognizer: null,
        ));
      } else {
        spans.add(TextSpan(
          text: matched,
          style: TextStyle(
            color: isMyMessage
                ? const Color(0xFFB8E0FF)
                : c.primary,
            fontFamily: 'Outfit',
            decoration: TextDecoration.underline,
          ),
          recognizer: null,
        ));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: TextStyle(color: textColor, fontFamily: 'Outfit')));
    }

    return RichText(
        text: TextSpan(
            children: spans,
            style: const TextStyle(fontSize: 15)));
  }
}

// ── Reply Preview ─────────────────────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final ChatMessage? replyTo;
  final Map<String, dynamic>? replyToJson;
  final bool isMyMessage;
  final ThemeColors c;

  const _ReplyPreview({
    this.replyTo,
    this.replyToJson,
    required this.isMyMessage,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final data = replyTo != null
        ? {
            'content': replyTo!.content,
            'sender_name': replyTo!.senderName,
            'message_type': replyTo!.messageType,
          }
        : replyToJson ?? {};

    final type = (data['message_type'] as String?) ?? 'text';
    String preview;
    switch (type) {
      case 'voice':
        preview = '🎤 Voice Message';
        break;
      case 'image':
        preview = '🌄 Photo';
        break;
      case 'video':
        preview = '🎥 Video';
        break;
      case 'audio':
        preview = '🎵 Audio';
        break;
      case 'giphy_sticker':
        preview = '🎭 Sticker';
        break;
      case 'giphy_gif':
        preview = '🎬 GIF';
        break;
      default:
        preview = (data['content'] as String?) ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: isMyMessage
            ? const Color(0x33000000)
            : const Color(0x0F000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: isMyMessage ? Colors.white : c.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['sender_name'] as String?) ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: isMyMessage ? Colors.white : c.primary,
                    height: 1.14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: isMyMessage
                        ? Colors.white.withValues(alpha: 0.9)
                        : c.text.withValues(alpha: 0.75),
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Link Preview Card ─────────────────────────────────────────────────────────
class _LinkPreviewCard extends StatelessWidget {
  final Map<String, dynamic> preview;
  final bool isMyMessage;
  final ThemeColors c;

  const _LinkPreviewCard(
      {required this.preview,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final title = preview['title']?.toString() ?? '';
    final desc = preview['description']?.toString() ?? '';
    final image = preview['image']?.toString();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isMyMessage
            ? Colors.white.withOpacity(0.12)
            : c.border.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: CachedNetworkImage(
                  imageUrl: image,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: isMyMessage ? Colors.white : c.text)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isMyMessage
                              ? Colors.white70
                              : c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time + Status row ──────────────────────────────────────────────────────────
class _TimeStatus extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _TimeStatus(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);
    final color = isMyMessage
        ? Colors.white.withOpacity(0.65)
        : c.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('edited',
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    fontStyle: FontStyle.italic,
                    color: color)),
          ),
        Text(timeStr,
            style: TextStyle(
                fontSize: 11, fontFamily: 'Outfit', color: color)),
        if (isMyMessage) ...[
          const SizedBox(width: 4),
          _statusIcon(color),
        ],
      ],
    );
  }

  Widget _statusIcon(Color color) {
    // Matches RN ChatConversation.jsx tick logic exactly:
    // failed → red error icon
    // pending_sync / pending → grey clock
    // is_read → done-all blue
    // otherwise (sent/delivered) → done-all grey
    if (message.status == 'failed') {
      return Icon(Icons.error_outline, size: 14, color: c.error);
    }
    if (message.syncStatus == 'pending_sync' || message.status == 'pending') {
      return Icon(Icons.schedule, size: 14, color: color);
    }
    if (message.isRead || message.status == 'read') {
      return Icon(Icons.done_all, size: 14,
          color: isMyMessage ? const Color(0xFF90CAF9) : c.primary);
    }
    // sent or delivered — grey double tick
    return Icon(Icons.done_all, size: 14, color: color);
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:$m $period';
  }
}

// ── Image Bubble ──────────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final VoidCallback? onTap;
  final ThemeColors c;

  const _ImageBubble({
    required this.message,
    required this.isMyMessage,
    this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final mediaData = message.mediaData;
    final naturalW = (mediaData?['width'] as num?)?.toDouble();
    final naturalH = (mediaData?['height'] as num?)?.toDouble();
    double w = 220, h = 200;
    if (naturalW != null &&
        naturalH != null &&
        naturalW > 0 &&
        naturalH > 0) {
      final maxW = MediaQuery.of(context).size.width * 0.6;
      final maxH = 320.0;
      w = naturalW;
      h = naturalH;
      if (w > maxW) {
        h = h * maxW / w;
        w = maxW;
      }
      if (h > maxH) {
        w = w * maxH / h;
        h = maxH;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 16),
        ),
        child: Stack(children: [
          CachedNetworkImage(
            imageUrl: message.mediaUrl ?? '',
            width: w,
            height: h,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
                width: w,
                height: h,
                color: c.surface),
            errorWidget: (_, __, ___) => Container(
              width: w,
              height: h,
              color: c.surface,
              child: Icon(Icons.broken_image,
                  color: c.textTertiary),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _TimeStatus(
                  message: message,
                  isMyMessage: isMyMessage,
                  c: c),
            ),
          ),
          if (message.content.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                color: Colors.black.withOpacity(0.4),
                child: Text(
                  message.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Outfit'),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Voice Bubble ──────────────────────────────────────────────────────────────
class _VoiceBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _VoiceBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMyMessage ? c.primary : c.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 18),
        ),
      ),
      child: Column(
        children: [
          VoiceMessagePlayer(
            audioUrl: message.mediaUrl ?? '',
            isMyMessage: isMyMessage,
            duration: (message.mediaData?['duration'] as num?)
                ?.toDouble(),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _TimeStatus(
                message: message,
                isMyMessage: isMyMessage,
                c: c),
          ),
        ],
      ),
    );
  }
}

// ── Poll Bubble ───────────────────────────────────────────────────────────────
class _PollBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _PollBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final pollData = message.pollData;
    if (pollData == null) {
      return _TextBubble(
        message: message,
        isMyMessage: isMyMessage,
        bubbleColor: isMyMessage ? c.primary : c.surface,
        textColor: isMyMessage ? Colors.white : c.text,
        c: c,
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: isMyMessage ? c.primary : c.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 18),
        ),
      ),
      child: PollMessageWidget(
        pollData: pollData,
        messageId: message.id,
        isMyMessage: isMyMessage,
        conversationId: message.conversationId,
      ),
    );
  }
}

// ── Giphy / GIF Bubble ────────────────────────────────────────────────────────
class _GiphyBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _GiphyBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final isSticker = message.messageType == 'giphy_sticker';
    final maxSize = isSticker ? 120.0 : 250.0;
    final aspectRatio =
        (message.mediaData?['aspectRatio'] as num?)?.toDouble() ?? 1.0;

    double w = maxSize;
    double h = maxSize / aspectRatio;
    if (h > maxSize) {
      w = maxSize * aspectRatio;
      h = maxSize;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: CachedNetworkImage(
        imageUrl: message.mediaUrl ?? '',
        width: w.toDouble(),
        height: h.toDouble(),
        fit: BoxFit.cover,
      ),
    );
  }
}

// ── Video Bubble ──────────────────────────────────────────────────────────────
class _VideoBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _VideoBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 160,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 16),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (message.mediaData?['thumbnail'] != null)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
                bottomRight:
                    Radius.circular(isMyMessage ? 4 : 16),
              ),
              child: CachedNetworkImage(
                imageUrl:
                    message.mediaData!['thumbnail'] as String,
                width: 220,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow,
                color: Colors.white, size: 28),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _TimeStatus(
                  message: message,
                  isMyMessage: isMyMessage,
                  c: c),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Audio Bubble ──────────────────────────────────────────────────────────────
class _AudioBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _AudioBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return _VoiceBubble(
        message: message, isMyMessage: isMyMessage, c: c);
  }
}

// ── Shared Post Bubble ────────────────────────────────────────────────────────
class _SharedPostBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _SharedPostBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata;
    final postImage = meta?['image'] ??
        meta?['media_url'] ??
        meta?['thumbnail'];
    final postTitle =
        meta?['caption'] ?? meta?['title'] ?? 'Shared Post';
    final authorName = meta?['author_name'] ?? meta?['username'];

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMyMessage ? c.primary : c.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
          bottomRight: Radius.circular(isMyMessage ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (postImage != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
              child: CachedNetworkImage(
                  imageUrl: postImage as String,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.article_outlined,
                      size: 14,
                      color: isMyMessage
                          ? Colors.white70
                          : c.textTertiary),
                  const SizedBox(width: 4),
                  Text('Shared Post',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isMyMessage
                              ? Colors.white70
                              : c.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text(
                  postTitle as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color:
                        isMyMessage ? Colors.white : c.text,
                  ),
                ),
                if (authorName != null) ...[
                  const SizedBox(height: 2),
                  Text(authorName as String,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isMyMessage
                              ? Colors.white70
                              : c.textSecondary)),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TimeStatus(
                      message: message,
                      isMyMessage: isMyMessage,
                      c: c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── System Message ────────────────────────────────────────────────────────────
class _SystemMessage extends StatelessWidget {
  final ChatMessage message;
  final ThemeColors c;

  const _SystemMessage(
      {required this.message, required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontFamily: 'Outfit',
              color: c.textSecondary),
        ),
      ),
    );
  }
}

// ── Deleted Message ───────────────────────────────────────────────────────────
class _DeletedMessage extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _DeletedMessage({
    required this.message,
    required this.isMyMessage,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface.withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                Radius.circular(isMyMessage ? 18 : 4),
            bottomRight:
                Radius.circular(isMyMessage ? 4 : 18),
          ),
          border: Border.all(
              color: c.border.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block,
              size: 14,
              color: c.textTertiary),
          const SizedBox(width: 6),
          Text(
            isMyMessage
                ? 'You deleted this message'
                : 'This message was deleted',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Outfit',
              fontStyle: FontStyle.italic,
              color: c.textTertiary,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Reactions Row ─────────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final bool isMyMessage;
  final String? currentUserId;
  final void Function(String emoji)? onTap;
  final ThemeColors c;

  const _ReactionsRow({
    required this.reactions,
    required this.isMyMessage,
    this.currentUserId,
    this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    // Group by emoji
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in reactions) {
      final emoji = (r['emoji'] as String?) ?? '';
      if (emoji.isEmpty) continue;
      grouped.putIfAbsent(emoji, () => []).add(r);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: grouped.entries.map((e) {
        final emoji = e.key;
        final count = e.value.length;
        final iMine = currentUserId != null &&
            e.value
                .any((r) => r['user_id'].toString() == currentUserId);
        return GestureDetector(
          onTap: () => onTap?.call(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iMine
                  ? c.primary.withOpacity(0.15)
                  : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: iMine
                    ? c.primary.withOpacity(0.4)
                    : c.border,
                width: 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  count.toString(),
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: iMine ? c.primary : c.textSecondary),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date Divider ──────────────────────────────────────────────────────────────
class DateDivider extends StatelessWidget {
  final DateTime date;
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday =
        DateTime(now.year, now.month, now.day - 1);
    final msgDay =
        DateTime(date.year, date.month, date.day);

    String label;
    if (msgDay == today) {
      label = 'Today';
    } else if (msgDay == yesterday) {
      label = 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      const days = [
        'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      label = days[date.weekday - 1];
    } else {
      label = '${date.day} ${_monthName(date.month)} ${date.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'Outfit',
                color: c.textSecondary,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// ── Swipe-to-reply wrapper ─────────────────────────────────────────────────────
// Mirrors SwipeableMessage from ChatConversation.jsx.
// All messages swipe right to reveal the reply icon (threshold: 30px, cap: 60px).
class _SwipeToReply extends StatefulWidget {
  final bool isMyMessage;
  final VoidCallback onReply;
  final ThemeColors c;
  final Widget child;

  const _SwipeToReply({
    required this.isMyMessage,
    required this.onReply,
    required this.c,
    required this.child,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _drag = 0;
  bool _triggered = false;

  static const _threshold = 30.0;
  static const _maxDrag = 60.0;

  void _onHorizontalUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (delta < 0 && _drag == 0) return; // only swipe right

    setState(() {
      _drag = math.max(0.0, math.min(_maxDrag, _drag + delta));
    });

    if (!_triggered && _drag >= _threshold) {
      _triggered = true;
    }
  }

  void _onHorizontalEnd(DragEndDetails _) {
    if (_triggered) widget.onReply();
    setState(() {
      _drag = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconOpacity = (_drag / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalUpdate,
      onHorizontalDragEnd: _onHorizontalEnd,
      child: Stack(
        children: [
          // Reply icon fades in on the left as user drags right
          if (_drag > 4)
            Positioned(
              left: math.max(4, _drag - 32),
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: iconOpacity,
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * iconOpacity,
                    child: Icon(
                      Icons.reply,
                      size: 24,
                      color: widget.c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
