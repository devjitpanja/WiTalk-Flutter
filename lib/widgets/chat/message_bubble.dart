import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';
import 'package:dio/dio.dart';
import '../../api/dio_client.dart';
import 'voice_message_player.dart';
import 'poll_message.dart';
import 'message_reactions.dart';
import '../../cache/witalk_image_cache.dart';

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
  final String? senderRole; // 'super_admin' | 'admin' | null
  final String? senderAdminTitle; // custom admin title
  final String? currentUserId; // needed for reaction highlight
  final String? otherUserName; // for resolving reply sender name (1:1 chats)
  final ChatMessage? replyToMessage;
  final bool isHighlighted; // scroll-to target highlight
  final VoidCallback? onLongPress;
  final void Function(ChatMessage)? onReplySwipe;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onTapAvatar;
  final VoidCallback? onTapImage;
  final VoidCallback? onReplyTap; // tap reply preview → scroll to original

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.showAvatar = false,
    this.senderName,
    this.senderRole,
    this.senderAdminTitle,
    this.currentUserId,
    this.otherUserName,
    this.replyToMessage,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReplySwipe,
    this.onReactionTap,
    this.onTapAvatar,
    this.onTapImage,
    this.onReplyTap,
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

    Widget bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isHighlighted ? c.primary.withValues(alpha: 0.15) : Colors.transparent,
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
                    senderRole: senderRole,
                    senderAdminTitle: senderAdminTitle,
                    replyToMessage: replyToMessage,
                    onTapImage: onTapImage,
                    onReplyTap: onReplyTap,
                    c: c,
                    currentUserId: currentUserId,
                    otherUserName: otherUserName,
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
                onRemoveReaction: onReactionTap,
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
  final String? senderRole;
  final String? senderAdminTitle;
  final ChatMessage? replyToMessage;
  final VoidCallback? onTapImage;
  final VoidCallback? onReplyTap;
  final ThemeColors c;
  final String? currentUserId;
  final String? otherUserName;

  const _BubbleContent({
    required this.message,
    required this.isMyMessage,
    this.senderName,
    this.senderRole,
    this.senderAdminTitle,
    this.replyToMessage,
    this.onTapImage,
    this.onReplyTap,
    required this.c,
    this.currentUserId,
    this.otherUserName,
  });

  Color get _bubbleColor => isMyMessage
      ? const Color(0xFF5160FF)
      : c.surface;

  Color get _textColor =>
      isMyMessage ? Colors.white : c.text;

  static final _addaRegex =
      RegExp(r'https?://witalk\.in/adda/([a-zA-Z0-9_-]+)', caseSensitive: false);
  // Any witalk.in URL that is NOT an adda/post/mini/video link gets a card bubble
  static final _witalkRegex =
      RegExp(r'https?://witalk\.in/([^\s/?#]+)(?:/([^\s/?#]*))?', caseSensitive: false);
  // These path prefixes are NOT entity links — skip card rendering for them
  static const _witalkSkipPrefixes = {
    'adda', 'p', 'm', 'post', 'video', 'mini',
  };

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
      case 'shared_reel':
        return _SharedPostBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      case 'shared_topic':
        return _SharedTopicBubble(
            message: message, isMyMessage: isMyMessage, c: c);
      default:
        final content = message.content;
        if (content.isNotEmpty) {
          // 1. Adda room links — dedicated invite card
          final addaMatch = _addaRegex.firstMatch(content);
          if (addaMatch != null) {
            return _AddaChatBubble(
              message: message,
              isMyMessage: isMyMessage,
              addaId: addaMatch.group(1) ?? '',
              c: c,
            );
          }
          // 2. Any other witalk.in URL → profile/group/community card
          //    (username slugs, /group/code, /groupchat/id, etc.)
          final witalkMatch = _witalkRegex.firstMatch(content);
          if (witalkMatch != null) {
            final first = witalkMatch.group(1) ?? '';
            if (!_witalkSkipPrefixes.contains(first.toLowerCase())) {
              return _WiTalkLinkBubble(
                message: message,
                isMyMessage: isMyMessage,
                url: witalkMatch.group(0)!,
                linkType: first,
                c: c,
                currentUserId: currentUserId,
              );
            }
          }
        }
        return _TextBubble(
          message: message,
          isMyMessage: isMyMessage,
          senderName: senderName,
          senderRole: senderRole,
          senderAdminTitle: senderAdminTitle,
          replyToMessage: replyToMessage,
          bubbleColor: _bubbleColor,
          textColor: _textColor,
          onReplyTap: onReplyTap,
          c: c,
          currentUserId: currentUserId,
          otherUserName: otherUserName,
        );
    }
  }
}

// ── Text Bubble ────────────────────────────────────────────────────────────────
class _TextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final String? senderName;
  final String? senderRole;
  final String? senderAdminTitle;
  final ChatMessage? replyToMessage;
  final Color bubbleColor;
  final Color textColor;
  final VoidCallback? onReplyTap;
  final ThemeColors c;
  final String? currentUserId;
  final String? otherUserName;

  const _TextBubble({
    required this.message,
    required this.isMyMessage,
    this.senderName,
    this.senderRole,
    this.senderAdminTitle,
    this.replyToMessage,
    required this.bubbleColor,
    required this.textColor,
    this.onReplyTap,
    required this.c,
    this.currentUserId,
    this.otherUserName,
  });

  bool get _isOwner => senderRole == 'super_admin';

  String? get _adminBadgeLabel {
    if (senderRole == 'super_admin') return 'Owner';
    if (senderRole == 'admin') {
      return (senderAdminTitle != null && senderAdminTitle!.trim().isNotEmpty)
          ? senderAdminTitle!.trim()
          : 'Admin';
    }
    return null;
  }

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
          // Group chat sender name + admin badge
          if (senderName != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                  if (_adminBadgeLabel != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _isOwner
                            ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                            : c.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isOwner
                              ? const Color(0xFFFFD700)
                              : c.primary.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        _adminBadgeLabel!,
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          color: _isOwner ? const Color(0xFFB8860B) : c.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          // Reply preview (tappable — scrolls to original)
          if (replyToMessage != null || message.replyTo != null)
            GestureDetector(
              onTap: onReplyTap,
              child: _ReplyPreview(
                replyTo: replyToMessage,
                replyToJson: message.replyTo,
                isMyMessage: isMyMessage,
                currentUserId: currentUserId,
                otherUserName: otherUserName,
                c: c,
              ),
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

  static final _tokenRegex = RegExp(r'(https?://[^\s]+)|(@\w+)');

  void _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Route witalk.in deep links in-app
    if (uri.host == 'witalk.in' || uri.host == 'www.witalk.in') {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) {
        final first = segs[0];
        if (first == 'adda' && segs.length >= 2) {
          context.push('/live-audio/${segs[1]}');
          return;
        }
        if (first == 'group' && segs.length >= 2) {
          context.push('/chat/join-group', extra: {'inviteCode': segs[1]});
          return;
        }
        if (first == 'groupchat' && segs.length >= 2) {
          context.push('/chat/group/${segs[1]}');
          return;
        }
        if (first == 'user' && segs.length >= 2) {
          context.push('/user/${segs[1]}');
          return;
        }
      }
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _tokenRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: textColor, fontSize: 15, fontFamily: 'Outfit'),
      );
    }

    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in matches) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, match.start),
            style: TextStyle(color: textColor, fontFamily: 'Outfit')));
      }
      final matched = match.group(0)!;
      if (matched.startsWith('@')) {
        // @mention — navigate to user profile
        final username = matched.substring(1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => context.push('/user/$username'),
            child: Text(
              matched,
              style: TextStyle(
                color: isMyMessage ? const Color(0xFF93C5FD) : c.primary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ));
      } else {
        // URL — open in-app or external
        final url = matched;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _openUrl(context, url),
            child: Text(
              url,
              style: TextStyle(
                color: isMyMessage ? const Color(0xFFB8E0FF) : c.primary,
                fontFamily: 'Outfit',
                fontSize: 15,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: TextStyle(color: textColor, fontFamily: 'Outfit')));
    }

    return Text.rich(TextSpan(children: spans, style: const TextStyle(fontSize: 15)));
  }
}

// ── Reply Preview ─────────────────────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final ChatMessage? replyTo;
  final Map<String, dynamic>? replyToJson;
  final bool isMyMessage;
  final String? currentUserId;
  final String? otherUserName;
  final ThemeColors c;

  const _ReplyPreview({
    this.replyTo,
    this.replyToJson,
    required this.isMyMessage,
    this.currentUserId,
    this.otherUserName,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final data = replyTo != null
        ? {
            'content': replyTo!.content,
            'sender_name': replyTo!.senderName,
            'sender_id': replyTo!.senderId,
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

    // Resolve sender name: mirror RN logic —
    // sender_id == currentUserId → 'You', otherwise use otherUserName or stored sender_name
    final senderId = (data['sender_id'] as String?) ?? '';
    final storedName = (data['sender_name'] as String?) ?? '';
    String displayName;
    if (senderId.isNotEmpty && currentUserId != null && senderId == currentUserId) {
      displayName = 'You';
    } else if (otherUserName != null && otherUserName!.isNotEmpty) {
      displayName = otherUserName!;
    } else if (storedName.isNotEmpty) {
      displayName = storedName;
    } else {
      displayName = 'Unknown';
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
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    displayName,
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
            ? Colors.white.withValues(alpha: 0.12)
            : c.border.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
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
        ? Colors.white.withValues(alpha: 0.65)
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
          color: isMyMessage ? Colors.white : c.primary);
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

// Expose _TimeStatus._formatTime for use in other private widgets in this file.
String _fmtMsgTime(DateTime dt) => _TimeStatus._formatTime(dt);

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
        cacheManager: WiTalkImageCache(),
            imageUrl: message.mediaUrl ?? '',
            width: w,
            height: h,
            fit: BoxFit.cover,
            placeholder: (ctx2, unused1) => Container(
                width: w,
                height: h,
                color: c.surface),
            errorWidget: (ctx2, unused1, unused2) => Container(
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
                color: Colors.black.withValues(alpha: 0.45),
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
                color: Colors.black.withValues(alpha: 0.4),
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
        color: isMyMessage ? const Color(0xFF5160FF) : c.surface,
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
        bubbleColor: isMyMessage ? const Color(0xFF5160FF) : c.surface,
        textColor: isMyMessage ? Colors.white : c.text,
        c: c,
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: isMyMessage ? const Color(0xFF5160FF) : c.surface,
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
// GIFs start paused (static frame). Tap to play; auto-stop after 3 loops (~9s).
// Stickers play on tap and loop continuously until tapped again.
class _GiphyBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _GiphyBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  State<_GiphyBubble> createState() => _GiphyBubbleState();
}

class _GiphyBubbleState extends State<_GiphyBubble> {
  late bool _playing;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    // Stickers autoplay immediately; GIFs start paused
    _playing = widget.message.messageType == 'giphy_sticker';
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    final isSticker = widget.message.messageType == 'giphy_sticker';
    if (_playing) {
      _autoStopTimer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      if (!isSticker) {
        // Auto-stop GIF after ~9 seconds (approx 3 loops)
        _autoStopTimer = Timer(const Duration(seconds: 9), () {
          if (mounted) setState(() => _playing = false);
        });
      }
    }
  }

  String _staticUrl(String animatedUrl) {
    // Giphy static URL: replace /giphy.gif with /giphy_s.gif
    if (animatedUrl.contains('/giphy.gif')) {
      return animatedUrl.replaceFirst('/giphy.gif', '/giphy_s.gif');
    }
    if (animatedUrl.contains('/200.gif')) {
      return animatedUrl.replaceFirst('/200.gif', '/200_s.gif');
    }
    return animatedUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isSticker = widget.message.messageType == 'giphy_sticker';
    final maxSize = isSticker ? 120.0 : 250.0;
    final aspectRatio =
        (widget.message.mediaData?['aspectRatio'] as num?)?.toDouble() ?? 1.0;

    double w = maxSize;
    double h = maxSize / aspectRatio;
    if (h > maxSize) {
      w = maxSize * aspectRatio;
      h = maxSize;
    }

    final animatedUrl = widget.message.mediaUrl ?? '';
    final staticUrl = _staticUrl(animatedUrl);

    final timeStatus = _TimeStatus(
      message: widget.message,
      isMyMessage: widget.isMyMessage,
      c: widget.c,
    );

    if (isSticker) {
      return GestureDetector(
        onTap: _toggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
              imageUrl: _playing ? animatedUrl : staticUrl,
              width: w,
              height: h,
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: timeStatus,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                imageUrl: _playing ? animatedUrl : staticUrl,
                width: w,
                height: h,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
              ),
              if (!_playing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: timeStatus,
                ),
              ),
            ],
          ),
        ),
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
        cacheManager: WiTalkImageCache(),
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
// Two layouts matching RN's SharedPostCard.jsx:
//   - Reel/video (postType=='video'||'mini'): 4:5 portrait with header overlay + play button
//   - Regular post: media image + header + caption below
class _SharedPostBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _SharedPostBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  void _navigate(BuildContext context) {
    final meta = message.metadata;
    if (meta == null) return;
    final postType = meta['postType']?.toString() ?? meta['type']?.toString() ?? '';
    final suffix = meta['suffix']?.toString();
    final postId = meta['postId']?.toString() ?? meta['post_id']?.toString();

    if (postType == 'video' || postType == 'mini') {
      // Navigate to MiniScreen (reel viewer)
      context.push('/mini', extra: {
        'posts': [meta],
        'initialIndex': 0,
      });
    } else if (suffix != null && suffix.isNotEmpty) {
      context.push('/post-view/$suffix');
    } else if (postId != null && postId.isNotEmpty) {
      context.push('/post/$postId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata;
    final postType = meta?['postType']?.toString() ?? '';
    final isReel = postType == 'video' || postType == 'mini';

    // Media: prefer thumbnail for video, then media_url, then image
    final mediaUrl = (meta?['thumbnail_url'] ?? meta?['media_url'] ?? meta?['image'])?.toString();
    final videoUrl = (meta?['video_url'] ?? meta?['media_url'])?.toString();
    final caption = (meta?['content'] ?? meta?['caption'] ?? meta?['title'] ?? '').toString();
    final name = (meta?['name'])?.toString();
    final username = (meta?['username'])?.toString();
    final profilePic = (meta?['profile_pic'])?.toString();

    if (isReel) {
      return _buildReelLayout(context, mediaUrl, videoUrl, name, username, profilePic);
    }
    return _buildRegularLayout(context, mediaUrl, caption, name, username, profilePic);
  }

  // 4:5 portrait card matching RN's video/mini layout
  Widget _buildReelLayout(BuildContext context, String? mediaUrl, String? videoUrl, String? name, String? username, String? profilePic) {
    const width = 220.0;
    const height = 275.0; // 4:5

    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
            bottomRight: Radius.circular(isMyMessage ? 4 : 18),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail / media background
            if (mediaUrl != null && mediaUrl.isNotEmpty)
              CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (ctx2, unused1) => Container(color: Colors.black26),
                errorWidget: (ctx2, unused1, unused2) => Container(color: Colors.black26),
              )
            else
              Container(color: Colors.black38),

            // Dark gradient overlay (top + bottom)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                    stops: const [0, 0.3, 0.7, 1],
                  ),
                ),
              ),
            ),

            // Header: avatar + username (top-left)
            if (name != null || username != null)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    if (profilePic != null)
                      ClipOval(
                        child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                          imageUrl: profilePic,
                          width: 26, height: 26,
                          fit: BoxFit.cover,
                          errorWidget: (ctx2, unused1, unused2) => CircleAvatar(
                            radius: 13,
                            backgroundColor: Colors.white24,
                            child: Text(
                              (name ?? username ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.white24,
                        child: Text(
                          (name ?? username ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name ?? '@${username ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Centered play button
            Center(
              child: Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              ),
            ),

            // Mini/reel icon — bottom left
            const Positioned(
              bottom: 8, left: 10,
              child: Icon(Icons.video_collection, size: 15, color: Colors.white70),
            ),

            // Timestamp — bottom right
            Positioned(
              bottom: 6, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _TimeStatus(message: message, isMyMessage: isMyMessage, c: c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Regular post layout: media on top, header + caption below
  Widget _buildRegularLayout(BuildContext context, String? mediaUrl, String caption, String? name, String? username, String? profilePic) {
    final displayName = name ?? username;
    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMyMessage ? const Color(0xFF5160FF) : c.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
            bottomRight: Radius.circular(isMyMessage ? 4 : 18),
          ),
          border: isMyMessage ? null : Border.all(color: c.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post media
            if (mediaUrl != null && mediaUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                  imageUrl: mediaUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (ctx2, unused1) => Container(height: 160, color: c.surface),
                  errorWidget: (ctx2, unused1, unused2) => Container(
                    height: 80,
                    color: c.surface,
                    child: Icon(Icons.image_not_supported_outlined, color: c.textTertiary),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender header
                  if (displayName != null)
                    Row(
                      children: [
                        if (profilePic != null)
                          ClipOval(
                            child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                              imageUrl: profilePic,
                              width: 20, height: 20,
                              fit: BoxFit.cover,
                              errorWidget: (ctx2, unused1, unused2) => CircleAvatar(
                                radius: 10,
                                backgroundColor: isMyMessage ? Colors.white24 : c.border,
                                child: Text(displayName[0].toUpperCase(),
                                    style: TextStyle(
                                        color: isMyMessage ? Colors.white : c.text,
                                        fontSize: 9)),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: isMyMessage ? Colors.white24 : c.border,
                            child: Text(displayName[0].toUpperCase(),
                                style: TextStyle(
                                    color: isMyMessage ? Colors.white : c.text,
                                    fontSize: 9)),
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: isMyMessage ? Colors.white : c.text,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (displayName != null) const SizedBox(height: 4),

                  // "Shared Post" label
                  Row(children: [
                    Icon(Icons.article_outlined,
                        size: 13,
                        color: isMyMessage ? Colors.white70 : c.textTertiary),
                    const SizedBox(width: 4),
                    Text('Shared Post',
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Outfit',
                            color: isMyMessage ? Colors.white70 : c.textSecondary)),
                  ]),

                  // Caption
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        color: isMyMessage ? Colors.white : c.text,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _TimeStatus(message: message, isMyMessage: isMyMessage, c: c),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Topic Bubble ───────────────────────────────────────────────────────
class _SharedTopicBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final ThemeColors c;

  const _SharedTopicBubble(
      {required this.message,
      required this.isMyMessage,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata;
    final title = meta?['title'] ?? meta?['name'] ?? 'Shared Topic';
    final image = meta?['image'] ?? meta?['thumbnail'];
    final authorName = meta?['author_name'] ?? meta?['group_name'];

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMyMessage ? const Color(0xFF5160FF) : c.surface,
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
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                  imageUrl: image as String,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.topic,
                      size: 14,
                      color: isMyMessage ? Colors.white70 : c.textTertiary),
                  const SizedBox(width: 4),
                  Text('Shared Topic',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isMyMessage ? Colors.white70 : c.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text(title as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: isMyMessage ? Colors.white : c.text)),
                if (authorName != null) ...[
                  const SizedBox(height: 2),
                  Text(authorName as String,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isMyMessage ? Colors.white70 : c.textSecondary)),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TimeStatus(message: message, isMyMessage: isMyMessage, c: c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Adda Chat Bubble (witalk.in/adda/...) ─────────────────────────────────────
// Mirrors AddaChatBubble.jsx exactly: fetches live status, shows wave bars,
// AUDIO/ENDED pill, Join/Ended button, footer.
class _AddaChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final String addaId;
  final ThemeColors c;

  const _AddaChatBubble({
    required this.message,
    required this.isMyMessage,
    required this.addaId,
    required this.c,
  });

  @override
  State<_AddaChatBubble> createState() => _AddaChatBubbleState();
}

class _AddaChatBubbleState extends State<_AddaChatBubble>
    with TickerProviderStateMixin {
  // 'checking' | 'live' | 'ended'
  String _liveStatus = 'checking';
  late final List<AnimationController> _waveCtrl;
  late final List<Animation<double>> _waveAnim;

  static const _endedAccent = Color(0xFF8B83B8);

  @override
  void initState() {
    super.initState();

    // 5 animated wave bars
    _waveCtrl = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + i * 60),
      );
    });
    _waveAnim = List.generate(5, (i) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _waveCtrl[i], curve: Curves.easeInOut),
      );
    });

    _fetchStatus();
  }

  void _startWaveAnimation() {
    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (mounted) _waveCtrl[i].repeat(reverse: true);
      });
    }
  }

  Future<void> _fetchStatus() async {
    if (widget.addaId.isEmpty) {
      if (mounted) setState(() => _liveStatus = 'ended');
      return;
    }
    try {
      final res = await dioClient.get('/v1/audio-rooms/${widget.addaId}');
      final room = res.data?['data'] ?? res.data;
      if (mounted) {
        final isLive = room != null && room['status'] == 'active';
        setState(() => _liveStatus = isLive ? 'live' : 'ended');
        if (isLive) _startWaveAnimation();
      }
    } catch (_) {
      if (mounted) setState(() => _liveStatus = 'ended');
    }
  }

  @override
  void dispose() {
    for (final c in _waveCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _liveStatus == 'live';
    final isChecking = _liveStatus == 'checking';
    final isEnded = _liveStatus == 'ended';

    final accent = widget.c.primaryButton; // #5B51F4
    final cardBg = isEnded ? widget.c.surface : accent;
    final topStripBg = isEnded
        ? _endedAccent.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.2);

    final textColor = isEnded ? widget.c.text : Colors.white;
    final subtitleColor = isEnded
        ? _endedAccent
        : Colors.white.withValues(alpha: 0.78);
    final timeColor = isEnded
        ? _endedAccent.withValues(alpha: 0.67)
        : Colors.white.withValues(alpha: 0.65);

    return GestureDetector(
      onTap: isLive ? () => context.push('/live-audio/${widget.addaId}') : null,
      onLongPress: null,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isEnded
              ? Border.all(color: _endedAccent.withValues(alpha: 0.25), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isEnded ? 0.08 : 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top strip: wave bars + badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: topStripBg,
              child: Row(
                children: [
                  // Wave bars
                  SizedBox(
                    height: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final barColor = isEnded
                            ? _endedAccent.withValues(alpha: 0.38)
                            : Colors.white.withValues(alpha: 0.85);
                        return Padding(
                          padding: EdgeInsets.only(right: i < 4 ? 3 : 0),
                          child: isLive
                              ? AnimatedBuilder(
                                  animation: _waveAnim[i],
                                  builder: (ctx2, unused1) => Container(
                                    width: 3,
                                    height: 20 * _waveAnim[i].value,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 3,
                                  height: 20 * 0.3,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                        );
                      }),
                    ),
                  ),
                  const Spacer(),
                  // Badge pill
                  isEnded
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _endedAccent.withValues(alpha: 0.094),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _endedAccent.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_off,
                                  size: 11, color: _endedAccent),
                              const SizedBox(width: 3),
                              const Text('ENDED',
                                  style: TextStyle(
                                      color: _endedAccent,
                                      fontSize: 10,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              const Text('AUDIO',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                ],
              ),
            ),

            // ── Body: icon circle + text ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isEnded
                          ? _endedAccent.withValues(alpha: 0.125)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEnded ? Icons.headset_off : Icons.headset_mic,
                      size: 22,
                      color: isEnded ? _endedAccent : accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnded
                              ? 'Adda Room'
                              : (widget.message.senderName.isNotEmpty
                                  ? widget.message.senderName
                                  : 'Adda Room'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEnded
                              ? 'This adda has ended'
                              : 'invited you to an Adda',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 12,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Join / Ended button ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              child: isEnded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _endedAccent.withValues(alpha: 0.082),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _endedAccent.withValues(alpha: 0.25),
                            width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.block,
                              size: 15, color: _endedAccent),
                          const SizedBox(width: 5),
                          const Text('Adda Ended',
                              style: TextStyle(
                                  color: _endedAccent,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: isLive ? () => context.push('/live-audio/${widget.addaId}') : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up, size: 15, color: accent),
                            const SizedBox(width: 5),
                            Text(
                              isChecking ? 'Loading...' : 'Join Adda',
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // ── Footer: time + read receipt ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _fmtMsgTime(widget.message.createdAt),
                    style: TextStyle(
                        color: timeColor,
                        fontSize: 11,
                        fontFamily: 'Outfit'),
                  ),
                  if (widget.isMyMessage) ...[
                    const SizedBox(width: 3),
                    Icon(
                      widget.message.isRead
                          ? Icons.done_all
                          : Icons.done_all,
                      size: 14,
                      color: isEnded
                          ? (widget.message.isRead
                              ? _endedAccent
                              : _endedAccent.withValues(alpha: 0.5))
                          : (widget.message.isRead
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.55)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── WiTalk Internal Link Bubble (profile, group, community invite links) ───────
// Mirrors WiTalkInternalLinkBubble.jsx exactly: fetches entity data, shows
// accent-color card with dots strip, type pill, avatar, name+meta, CTA, footer.
class _WiTalkLinkBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final String url;
  final String linkType; // path segment: 'profile'|'group'|'groupchat'|username…
  final ThemeColors c;
  final String? currentUserId;

  const _WiTalkLinkBubble({
    required this.message,
    required this.isMyMessage,
    required this.url,
    required this.linkType,
    required this.c,
    this.currentUserId,
  });

  @override
  State<_WiTalkLinkBubble> createState() => _WiTalkLinkBubbleState();
}

// Module-level cache so the same URL never fetches twice across list items.
final _witalkLinkCache = <String, Map<String, dynamic>?>{};

class _WiTalkLinkBubbleState extends State<_WiTalkLinkBubble> {
  bool _loading = true;
  Map<String, dynamic>? _data; // resolved card data

  @override
  void initState() {
    super.initState();
    final cached = _witalkLinkCache[widget.url];
    if (_witalkLinkCache.containsKey(widget.url)) {
      _loading = false;
      _data = cached;
    } else {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    debugPrint('[WiTalkBubble] _fetchData start → url="${widget.url}" linkType="${widget.linkType}"');
    try {
      final d = await _resolveWiTalkLink(widget.url, widget.linkType, widget.message.content);
      debugPrint('[WiTalkBubble] _fetchData result → ${d == null ? "NULL (fallback)" : "kind=${d['kind']}, name=${d['name']}"}');
      // Only cache successful resolutions; leave null-results uncached so retry is possible
      if (d != null) _witalkLinkCache[widget.url] = d;
      if (mounted) setState(() { _loading = false; _data = d; });
    } catch (e, st) {
      debugPrint('[WiTalkBubble] _fetchData ERROR: $e\n$st');
      if (mounted) setState(() { _loading = false; _data = null; });
    }
  }

  void _handleCta(BuildContext context) {
    final d = _data;
    if (d == null) return;
    final kind = d['kind'] as String? ?? '';
    switch (kind) {
      case 'profile':
        final userId = d['userId'] as String?;
        final username = d['username'] as String?;
        if (userId != null && userId.isNotEmpty) {
          context.push('/user/$userId');
        } else if (username != null && username.isNotEmpty) {
          context.push('/user/$username');
        }
        break;
      case 'group':
        // Mirrors RN App.jsx handleComplexDeepLink group/ logic:
        //   public community → CommunityInfoScreen
        //   private group    → GroupInviteBottomSheet
        final inviteCode = d['inviteCode'] as String?;
        final groupId = d['groupId'] as String?;
        final isPrivate = d['isPrivate'] == true;
        if (!isPrivate) {
          // Public community → CommunityInfoScreen (accepts either groupId or inviteCode)
          final target = groupId ?? inviteCode;
          if (target != null) context.push('/community-info/$target');
        } else {
          // Private group → bottom sheet
          final code = inviteCode ?? groupId;
          if (code != null) _showGroupInviteSheet(context, code);
        }
        break;
      case 'groupchat':
        final groupId = d['groupId'] as String?;
        if (groupId != null) context.push('/chat/group/$groupId');
        break;
      case 'channel':
        final channelId = d['channelId'] as String?;
        if (channelId != null) context.push('/channel/$channelId');
        break;
    }
  }

  void _showGroupInviteSheet(BuildContext context, String inviteCode) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupInviteSheet(inviteCode: inviteCode, c: widget.c, userId: widget.currentUserId),
    );
  }

  // Resolve any witalk.in URL to a typed card data map.
  // Mirrors RN's fetchWiTalkLinkData + channelAPI.getByUsername flow exactly.
  static Future<Map<String, dynamic>?> _resolveWiTalkLink(
      String url, String linkType, String content) async {
    final uri = Uri.tryParse(url);
    if (uri == null) { debugPrint('[WiTalkBubble] _resolveWiTalkLink: invalid URI "$url"'); return null; }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) { debugPrint('[WiTalkBubble] _resolveWiTalkLink: no path segments in "$url"'); return null; }

    final first = segments[0];
    debugPrint('[WiTalkBubble] _resolveWiTalkLink: first="$first" segments=$segments');

    // witalk.in/group/{inviteCode} — explicit group invite URL
    if (first == 'group' && segments.length >= 2) {
      return _resolveGroupInvite(segments[1]);
    }

    // witalk.in/groupchat/{groupId} — direct group chat link
    if (first == 'groupchat' && segments.length >= 2) {
      return _resolveGroupById(segments[1]);
    }

    // witalk.in/{slug} — could be username, group slug, or channel username.
    // Use the resolve endpoint (mirrors channelAPI.getByUsername) to determine type.
    final slug = first;
    // Guard: skip API call for slugs that can't be valid handles (same rule as channel_api.dart)
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,30}$').hasMatch(slug)) {
      debugPrint('[WiTalkBubble] _resolveWiTalkLink: slug "$slug" failed handle validation');
      return null;
    }
    try {
      debugPrint('[WiTalkBubble] GET /v1/username/resolve/${Uri.encodeComponent(slug)}');
      final resolveRes = await dioClient.get(
        '/v1/username/resolve/${Uri.encodeComponent(slug)}',
      );
      debugPrint('[WiTalkBubble] resolve response: ${resolveRes.statusCode} → ${resolveRes.data}');
      // Response shape is {type, data} directly — no outer wrapper
      final resolved = resolveRes.data as Map<String, dynamic>?;
      if (resolved == null) { debugPrint('[WiTalkBubble] resolve: data is null'); return null; }

      final resolvedType = resolved['type']?.toString();
      final resolvedData = resolved['data'] as Map<String, dynamic>?;
      debugPrint('[WiTalkBubble] resolvedType="$resolvedType" resolvedData=$resolvedData');

      if (resolvedType == 'user') {
        // resolvedData already has: id, username, name, picture — use it directly.
        // Fall back to a full profile fetch only if name is missing.
        Map<String, dynamic>? u = resolvedData;
        if (u == null || u['name'] == null) {
          debugPrint('[WiTalkBubble] resolve data missing name, fetching /v1/user/profile/$slug');
          final res = await dioClient.get('/v1/user/profile/${Uri.encodeComponent(slug)}');
          debugPrint('[WiTalkBubble] profile response: ${res.statusCode} → ${res.data}');
          u = res.data?['data']?['user'] ?? res.data?['data'] ?? res.data as Map<String, dynamic>?;
        }
        if (u == null || u['name'] == null) { debugPrint('[WiTalkBubble] profile: user/name is null'); return null; }
        final followers = u['followers_count'];
        return {
          'kind': 'profile',
          'name': u['name'].toString(),
          // resolve returns 'picture'; full profile returns 'profile_pic' — try both
          'avatarUrl': u['picture'] ?? u['profile_pic'],
          'meta': [
            if (u['username'] != null) '@${u['username']}',
            if (followers != null) '${_fmtCount(followers)} followers',
          ].join('  ·  '),
          'bio': u['bio'],
          'isVerified': u['is_verified'] == true,
          'ctaLabel': 'View Profile',
          'ctaIcon': Icons.person,
          'badgeLabel': 'PROFILE',
          'badgeIcon': Icons.person,
          'userId': u['id']?.toString(),
          'username': u['username']?.toString() ?? slug,
        };
      }

      if (resolvedType == 'channel') {
        final channelId = resolvedData?['id']?.toString();
        if (channelId == null) { debugPrint('[WiTalkBubble] channel: no id in resolvedData=$resolvedData'); return null; }
        debugPrint('[WiTalkBubble] GET /v1/channels/$channelId');
        final res = await dioClient.get('/v1/channels/$channelId');
        debugPrint('[WiTalkBubble] channel response: ${res.statusCode} → ${res.data}');
        final c = res.data?['channel'] ?? res.data?['data']?['channel'] ?? res.data?['data'] ?? res.data;
        if (c == null || c['name'] == null) { debugPrint('[WiTalkBubble] channel: c/name is null'); return null; }
        final subCount = c['subscriber_count'];
        return {
          'kind': 'channel',
          'name': c['name'].toString(),
          'avatarUrl': c['icon'] ?? c['avatar_url'],
          'meta': [
            if (c['username'] != null) '@${c['username']}',
            if (subCount != null) '${_fmtCount(subCount)} subscribers',
          ].join('  ·  '),
          'bio': c['description'],
          'isVerified': c['is_verified'] == true,
          'ctaLabel': 'View Channel',
          'ctaIcon': Icons.campaign,
          'badgeLabel': 'CHANNEL',
          'badgeIcon': Icons.campaign,
          'channelId': channelId,
        };
      }

      if (resolvedType == 'group') {
        final inviteCode = resolvedData?['invite_code']?.toString();
        if (inviteCode != null) return _resolveGroupInvite(inviteCode);
        final groupId = resolvedData?['id']?.toString();
        if (groupId != null) return _resolveGroupById(groupId);
        debugPrint('[WiTalkBubble] group: no inviteCode or id in resolvedData=$resolvedData');
        return null;
      }

      debugPrint('[WiTalkBubble] unhandled resolvedType="$resolvedType"');
    } catch (e, st) {
      debugPrint('[WiTalkBubble] _resolveWiTalkLink EXCEPTION: $e\n$st');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _resolveGroupInvite(String inviteCode) async {
    try {
      debugPrint('[WiTalkBubble] GET /v1/groups/invite/${Uri.encodeComponent(inviteCode)}');
      final res = await dioClient.get('/v1/groups/invite/${Uri.encodeComponent(inviteCode)}');
      debugPrint('[WiTalkBubble] groupInvite response: ${res.statusCode} → ${res.data}');
      final g = res.data?['data'] ?? res.data;
      if (g == null || g['name'] == null) { debugPrint('[WiTalkBubble] groupInvite: g/name is null'); return null; }
      final memberCount = g['member_count'];
      // Match RN isPrivate logic exactly
      final isPrivate = g['entity_type'] != null
          ? g['entity_type'] != 'community'
          : (g['group_type'] != null ? g['group_type'] != 'public' : g['is_private'] == true);
      final isCommunity = !isPrivate;
      return {
        'kind': 'group',
        'name': g['name'].toString(),
        'avatarUrl': g['picture'] ?? g['image_url'] ?? g['avatar_url'],
        'meta': [
          if (memberCount != null) '${_fmtCount(memberCount)} members',
          isCommunity ? 'Public' : 'Private',
        ].join('  ·  '),
        'bio': g['description'],
        'isPrivate': isPrivate,
        'ctaLabel': isCommunity ? 'Join Community' : 'Join Group',
        'ctaIcon': Icons.group,
        'badgeLabel': isCommunity ? 'COMMUNITY' : 'GROUP',
        'badgeIcon': Icons.groups,
        'inviteCode': inviteCode,
        'groupId': g['id']?.toString(),
      };
    } catch (e, st) { debugPrint('[WiTalkBubble] _resolveGroupInvite EXCEPTION: $e\n$st'); return null; }
  }

  static Future<Map<String, dynamic>?> _resolveGroupById(String groupId) async {
    try {
      debugPrint('[WiTalkBubble] GET /v1/groups/$groupId');
      final res = await dioClient.get('/v1/groups/$groupId');
      debugPrint('[WiTalkBubble] groupById response: ${res.statusCode} → ${res.data}');
      final g = res.data?['data'] ?? res.data;
      if (g == null || g['name'] == null) { debugPrint('[WiTalkBubble] groupById: g/name is null'); return null; }
      final memberCount = g['member_count'];
      final isPrivate = g['is_private'] == true;
      return {
        'kind': 'groupchat',
        'name': g['name'].toString(),
        'avatarUrl': g['image_url'] ?? g['avatar_url'],
        'meta': [
          if (memberCount != null) '${_fmtCount(memberCount)} members',
          isPrivate ? 'Private' : 'Public',
        ].join('  ·  '),
        'bio': g['description'],
        'isPrivate': isPrivate,
        'ctaLabel': 'Open Group',
        'ctaIcon': Icons.group,
        'badgeLabel': 'GROUP',
        'badgeIcon': Icons.groups,
        'groupId': groupId,
      };
    } catch (_) { return null; }
  }

  static String _fmtCount(dynamic n) {
    final v = (n is num) ? n.toDouble() : double.tryParse(n.toString()) ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.c.primaryButton; // #5B51F4

    if (_loading) {
      return _buildCard(
        accent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              child: Row(
                children: [
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Loading…',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontFamily: 'Outfit')),
                ],
              ),
            ),
            _footer(accent),
          ],
        ),
      );
    }

    if (_data == null) {
      // Fallback: plain link bubble
      return Container(
        constraints: const BoxConstraints(maxWidth: 248),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: widget.isMyMessage ? accent : widget.c.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMyMessage ? 16 : 4),
            bottomRight: Radius.circular(widget.isMyMessage ? 4 : 16),
          ),
          border: widget.isMyMessage
              ? null
              : Border.all(color: widget.c.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.url,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Outfit',
                color: widget.isMyMessage
                    ? Colors.white.withValues(alpha: 0.9)
                    : accent,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: _TimeStatus(
                  message: widget.message,
                  isMyMessage: widget.isMyMessage,
                  c: widget.c),
            ),
          ],
        ),
      );
    }

    final d = _data!;
    final name = d['name'] as String;
    final avatarUrl = d['avatarUrl'] as String?;
    final meta = d['meta'] as String? ?? '';
    final bio = d['bio'] as String?;
    final ctaLabel = d['ctaLabel'] as String;
    final ctaIcon = d['ctaIcon'] as IconData;
    final badgeLabel = d['badgeLabel'] as String;
    final badgeIcon = d['badgeIcon'] as IconData;
    final isVerified = d['isVerified'] == true;

    final initials = name.split(' ').map((w) => w.isEmpty ? '' : w[0]).join().substring(0, math.min(2, name.split(' ').map((w) => w.isEmpty ? '' : w[0]).join().length)).toUpperCase();

    return _buildCard(
      accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top strip: dots + type pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.black.withValues(alpha: 0.18),
            child: Row(
              children: [
                // Decorative dots (opacity gradient)
                Row(
                  children: List.generate(7, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15 + i * 0.1),
                    ),
                  )),
                ),
                const Spacer(),
                // Type pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(badgeLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body: avatar + text
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 2),
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                            imageUrl: avatarUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (ctx2, unused1, unused2) => Center(
                              child: Text(initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700)),
                        ),
                ),
                const SizedBox(width: 10),
                // Text block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 14, color: Colors.white),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontFamily: 'Outfit')),
                      ],
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(bio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontFamily: 'Outfit')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CTA button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: GestureDetector(
              onTap: () => _handleCta(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(ctaIcon, size: 14, color: accent),
                    const SizedBox(width: 5),
                    Text(ctaLabel,
                        style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          _footer(accent),
        ],
      ),
    );
  }

  Widget _buildCard(Color accent, {required Widget child}) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _footer(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _fmtMsgTime(widget.message.createdAt),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
                fontFamily: 'Outfit'),
          ),
          if (widget.isMyMessage) ...[
            const SizedBox(width: 3),
            Icon(Icons.done_all,
                size: 14,
                color: widget.message.isRead
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.55)),
          ],
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
          color: c.surface.withValues(alpha: 0.8),
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
          color: c.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                Radius.circular(isMyMessage ? 18 : 4),
            bottomRight:
                Radius.circular(isMyMessage ? 4 : 18),
          ),
          border: Border.all(
              color: c.border.withValues(alpha: 0.3)),
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
  final void Function(String emoji)? onRemoveReaction;
  final ThemeColors c;

  const _ReactionsRow({
    required this.reactions,
    required this.isMyMessage,
    this.currentUserId,
    this.onRemoveReaction,
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
          onTap: () {
            showModalBottomSheet(
              useRootNavigator: true,
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => MessageReactionSheet(
                reactions: reactions,
                currentUserId: currentUserId,
                onRemoveReaction: onRemoveReaction,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iMine
                  ? c.primary.withValues(alpha: 0.15)
                  : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: iMine
                    ? c.primary.withValues(alpha: 0.4)
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
          color: c.surface.withValues(alpha: 0.8),
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
  // Track whether this gesture is truly horizontal (set on first significant delta)
  bool? _isHorizontalGesture;

  static const _threshold = 48.0;  // raised to avoid accidental triggers
  static const _maxDrag = 70.0;

  void _onHorizontalUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    final dy = d.delta.dy;

    // On first movement, decide if horizontal or vertical
    if (_isHorizontalGesture == null && (dx.abs() + dy.abs()) > 2) {
      _isHorizontalGesture = dx.abs() > dy.abs() * 1.5;
    }

    // Reject vertical-dominant gestures (scrolling)
    if (_isHorizontalGesture == false) return;

    // Only swipe right (positive dx)
    if (dx < 0 && _drag == 0) return;

    setState(() {
      _drag = math.max(0.0, math.min(_maxDrag, _drag + dx));
    });

    if (!_triggered && _drag >= _threshold) {
      _triggered = true;
    }
  }

  void _onHorizontalEnd(DragEndDetails d) {
    // Also require minimum velocity to prevent accidental slow drags
    final vx = d.velocity.pixelsPerSecond.dx.abs();
    if (_triggered && vx > 80) widget.onReply();
    setState(() {
      _drag = 0;
      _triggered = false;
      _isHorizontalGesture = null;
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

// ── Group Invite Bottom Sheet ─────────────────────────────────────────────────
// Mirrors RN GroupInviteBottomSheet.jsx exactly:
//   private group → fetch details → show join/open/cancel-request/banned states
//   On join success → push /chat/group/{groupId}
class _GroupInviteSheet extends StatefulWidget {
  final String inviteCode;
  final ThemeColors c;
  final String? userId;
  const _GroupInviteSheet({required this.inviteCode, required this.c, this.userId});

  @override
  State<_GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends State<_GroupInviteSheet> {
  Map<String, dynamic>? _group;
  bool _loading = true;
  bool _joining = false;
  bool _canceling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      debugPrint('[GroupInviteSheet] fetching invite code: ${widget.inviteCode} userId=${widget.userId}');
      final params = <String, dynamic>{};
      if (widget.userId != null && widget.userId!.isNotEmpty) params['userId'] = widget.userId;
      final res = await dioClient.get(
        '/v1/groups/invite/${Uri.encodeComponent(widget.inviteCode)}',
        queryParameters: params,
      );
      final data = res.data?['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>?;
      debugPrint('[GroupInviteSheet] group data: is_member=${data?['is_member']} requires_approval=${data?['requires_approval']} can_join=${data?['can_join']} join_request=${data?['join_request']}');
      if (!mounted) return;
      setState(() { _loading = false; _group = data; if (data == null) _error = 'Group not found or invite link expired.'; });
    } catch (e) {
      debugPrint('[GroupInviteSheet] fetch error: $e');
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load group details.'; });
    }
  }

  Future<void> _join() async {
    if (_joining || _group == null) return;
    setState(() { _joining = true; _error = null; });
    try {
      final body = <String, dynamic>{'invite_code': widget.inviteCode};
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        body['user_id'] = widget.userId;
      }
      debugPrint('[GroupInviteSheet] POST /v1/groups/join body=$body');
      final res = await dioClient.post('/v1/groups/join', data: body);
      debugPrint('[GroupInviteSheet] join response: ${res.data}');
      final requiresApproval = res.data?['requiresApproval'] == true ||
          res.data?['data']?['requires_approval'] == true;
      if (!mounted) return;
      if (requiresApproval) {
        // Build join_request from the join response directly — no re-fetch needed
        final requestId = res.data?['data']?['request_id']?.toString();
        debugPrint('[GroupInviteSheet] requiresApproval=true, request_id=$requestId');
        if (mounted) {
          setState(() {
            _joining = false;
            if (requestId != null) {
              _group = Map<String, dynamic>.from(_group!)
                ..['join_request'] = {'id': requestId, 'status': 'pending'};
            }
          });
        }
      } else {
        final groupId = _group!['id']?.toString();
        if (!mounted) return;
        Navigator.of(context).pop();
        if (groupId != null) context.push('/chat/group/$groupId');
      }
    } on DioException catch (e) {
      debugPrint('[GroupInviteSheet] join DioException: status=${e.response?.statusCode} data=${e.response?.data}');
      if (!mounted) return;
      final serverMsg = e.response?.data?['message'] as String? ??
          e.response?.data?['error'] as String?;
      final serverCode = e.response?.data?['code'] as String? ?? '';
      final isPendingRequest = serverCode.toLowerCase().contains('pending') ||
          (serverMsg != null &&
              (serverMsg.toLowerCase().contains('pending') ||
                  serverMsg.toLowerCase().contains('already have a')));
      if (isPendingRequest) {
        // Re-fetch with userId so server returns personalized join_request field
        try {
          debugPrint('[GroupInviteSheet] REQUEST_PENDING → re-fetching group with userId=${widget.userId}');
          final params = <String, dynamic>{};
          if (widget.userId != null && widget.userId!.isNotEmpty) params['userId'] = widget.userId;
          final updated = await dioClient.get(
            '/v1/groups/invite/${Uri.encodeComponent(widget.inviteCode)}',
            queryParameters: params,
          );
          final data = updated.data?['data'] as Map<String, dynamic>?;
          debugPrint('[GroupInviteSheet] re-fetch result: join_request=${data?['join_request']} is_member=${data?['is_member']}');
          if (mounted) setState(() { _joining = false; if (data != null) _group = data; _error = null; });
        } catch (refetchErr) {
          debugPrint('[GroupInviteSheet] re-fetch failed: $refetchErr');
          if (mounted) setState(() { _joining = false; });
        }
        return;
      }
      final msg = serverMsg ??
          (e.toString().toLowerCase().contains('already')
              ? 'You are already a member of this group.'
              : 'Failed to join group. Please try again.');
      setState(() { _joining = false; _error = msg; });
    } catch (e) {
      debugPrint('[GroupInviteSheet] join error: $e');
      if (!mounted) return;
      final msg = e.toString().toLowerCase().contains('already')
          ? 'You are already a member of this group.'
          : 'Failed to join group. Please try again.';
      setState(() { _joining = false; _error = msg; });
    }
  }

  Future<void> _cancelRequest() async {
    final requestId = (_group?['join_request'] as Map<String, dynamic>?)?['id']?.toString();
    if (requestId == null || _canceling) return;
    setState(() { _canceling = true; _error = null; });
    try {
      await dioClient.delete('/v1/groups/join-requests/$requestId');
      final updated = await dioClient.get('/v1/groups/invite/${Uri.encodeComponent(widget.inviteCode)}');
      final data = updated.data?['data'] as Map<String, dynamic>?;
      if (mounted) setState(() { _canceling = false; if (data != null) _group = data; });
    } catch (_) {
      if (mounted) setState(() { _canceling = false; _error = 'Failed to cancel request.'; });
    }
  }

  void _openGroup() {
    final groupId = _group?['id']?.toString();
    Navigator.of(context).pop();
    if (groupId != null) context.push('/chat/group/$groupId');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 5,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 20),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                CircularProgressIndicator(color: c.primaryButton),
                const SizedBox(height: 12),
                Text('Loading group details…',
                    style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 15)),
              ]),
            )
          else if (_error != null && _group == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                Icon(Icons.error_outline, size: 56, color: c.error),
                const SizedBox(height: 12),
                Text('Unable to Load Group',
                    style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center,
                    style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 14)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Close', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            )
          else if (_group != null)
            _buildContent(c),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeColors c) {
    final g = _group!;

    if (g['is_banned'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          const Icon(Icons.block, size: 72, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          const Text("You're Banned",
              style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22)),
          const SizedBox(height: 10),
          Text('You have been banned from this group and cannot join or request to join.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14, height: 1.5)),
        ]),
      );
    }

    final name = g['name']?.toString() ?? 'Group';
    final description = g['description']?.toString();
    final picture = g['picture']?.toString() ?? g['image_url']?.toString();
    final memberCount = g['member_count'] as int? ?? 0;
    final isMember = g['is_member'] == true;
    final joinRequest = g['join_request'] as Map<String, dynamic>?;
    final requiresApproval = g['requires_approval'] == true;
    final canJoin = g['can_join'] != false;
    final restrictionReason = g['restriction_reason']?.toString();
    final isPublic = g['entity_type'] != null
        ? g['entity_type'] == 'community'
        : (g['group_type'] != null ? g['group_type'] == 'public' : g['is_private'] != true);
    final entityLabel = isPublic ? 'Community' : 'Group';

    return Column(children: [
      CircleAvatar(
        radius: 56,
        backgroundColor: c.primaryButton.withValues(alpha: 0.15),
        backgroundImage: picture != null ? CachedNetworkImageProvider(picture) : null,
        child: picture == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: c.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 36))
            : null,
      ),
      const SizedBox(height: 16),
      Text(name, textAlign: TextAlign.center,
          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 22)),
      const SizedBox(height: 6),
      if (description != null && description.isNotEmpty) ...[
        Text(description, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 14, height: 1.5)),
        const SizedBox(height: 12),
      ],
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people, size: 18, color: c.textTertiary),
        const SizedBox(width: 6),
        Text('$memberCount ${memberCount == 1 ? 'member' : 'members'}',
            style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 14)),
      ]),
      const SizedBox(height: 16),
      if (joinRequest != null)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.schedule, size: 20, color: c.textSecondary),
            const SizedBox(width: 8),
            Text('An admin must approve your request.',
                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13)),
          ]),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            requiresApproval && !isMember
                ? 'An admin must approve your request.'
                : 'You will be added to "$name" and its announcement group. Your profile will be visible to its admins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12, height: 1.5),
          ),
        ),
      const SizedBox(height: 20),
      if (_error != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFDC2626), fontFamily: 'Outfit', fontSize: 13)),
        ),
      SizedBox(
        width: double.infinity,
        child: isMember
            ? ElevatedButton(
                onPressed: _openGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Open $entityLabel',
                    style: TextStyle(color: c.background, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
              )
            : !canJoin
                ? Column(children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(restrictionReason ?? 'You cannot join this community',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFDC2626), fontFamily: 'Outfit', fontSize: 13)),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cannot Join',
                            style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ])
                : joinRequest != null
                    ? OutlinedButton(
                        onPressed: _canceling ? null : _cancelRequest,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _canceling
                            ? SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: c.text))
                            : Text('Cancel request',
                                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
                      )
                    : ElevatedButton(
                        onPressed: _joining ? null : _join,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.text,
                          disabledBackgroundColor: c.textTertiary.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _joining
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                requiresApproval ? 'Request to join' : 'Join $entityLabel',
                                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
      ),
    ]);
  }
}
