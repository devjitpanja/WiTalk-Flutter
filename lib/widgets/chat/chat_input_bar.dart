import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../theme/theme_colors.dart';
import '../../providers/chat_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/upload_service.dart';

// Mirrors ChatInputBar.jsx — imperative handle pattern
// Parent calls methods on ChatInputBarController to get text, clear, set text

class ChatInputBarController {
  _ChatInputBarState? _state;

  String get text => _state?._text ?? '';
  void clear() => _state?._clear();
  void setText(String t) => _state?._setText(t);
  void focus() => _state?._focusNode.requestFocus();
  ChatMessage? get replyingTo => _state?._replyingTo;
  ChatMessage? get editingMessage => _state?._editingMessage;
  void setReplyTo(ChatMessage? msg) => _state?._setReplyTo(msg);
  void setEditing(ChatMessage? msg) => _state?._setEditing(msg);
  void clearReply() => _state?._clearReply();
  void clearEditing() => _state?._clearEditing();
  Map<String, dynamic>? get composeLinkPreview =>
      _state?._composeLinkPreview;
  void clearLinkPreview() => _state?._composeLinkPreview = null;
}

class ChatInputBar extends StatefulWidget {
  final ChatInputBarController controller;
  final String conversationId;
  final String? otherUserName;
  final Map<String, dynamic>? otherUser;
  final String currentUserId;
  // Flags
  final bool isBlocked;
  final bool theyBlockedMe;
  final bool privacyBlocked;
  final String? privacyMessage;
  final bool isIncomingRequest;
  final bool isOutgoingRequest;
  final int sentMessageCount;
  final bool isRecordingVoice;
  final bool uploadingMedia;
  // Callbacks
  final VoidCallback onSend;
  final void Function(String conversationId) startTyping;
  final void Function(String conversationId) stopTyping;
  final Future<String?> Function() onPickAndSendImage;
  final VoidCallback onStartVoiceRecording;
  final VoidCallback? onAcceptRequest;
  final VoidCallback? onDeleteRequest;
  final VoidCallback? onBlockUnblock;
  final VoidCallback? onOpenGiphyPicker;
  final bool isGroup;
  final Map<String, dynamic>? groupInfo;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.currentUserId,
    this.otherUserName,
    this.otherUser,
    this.isBlocked = false,
    this.theyBlockedMe = false,
    this.privacyBlocked = false,
    this.privacyMessage,
    this.isIncomingRequest = false,
    this.isOutgoingRequest = false,
    this.sentMessageCount = 0,
    this.isRecordingVoice = false,
    this.uploadingMedia = false,
    required this.onSend,
    required this.startTyping,
    required this.stopTyping,
    required this.onPickAndSendImage,
    required this.onStartVoiceRecording,
    this.onAcceptRequest,
    this.onDeleteRequest,
    this.onBlockUnblock,
    this.onOpenGiphyPicker,
    this.isGroup = false,
    this.groupInfo,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  String _text = '';
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  bool _showEmoji = false;
  Map<String, dynamic>? _composeLinkPreview;
  Timer? _typingTimer;
  Timer? _linkPreviewTimer;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _linkPreviewTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (_isSending) return;
    setState(() => _text = text);

    // Typing indicator
    if (text.isNotEmpty) {
      _typingTimer?.cancel();
      widget.startTyping(widget.conversationId);
      _typingTimer =
          Timer(const Duration(seconds: 3), () {
        widget.stopTyping(widget.conversationId);
      });
    } else {
      _typingTimer?.cancel();
      widget.stopTyping(widget.conversationId);
    }

    // Link preview pre-fetch (debounce 400ms)
    _linkPreviewTimer?.cancel();
    if (text.trim().isNotEmpty) {
      _linkPreviewTimer = Timer(const Duration(milliseconds: 400), () {
        _fetchLinkPreview(text);
      });
    } else {
      setState(() => _composeLinkPreview = null);
    }
  }

  void _fetchLinkPreview(String text) async {
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
    if (urlMatch == null) {
      if (mounted) setState(() => _composeLinkPreview = null);
      return;
    }
    final url = urlMatch.group(0)!;
    try {
      final res = await dioClient.get(
        AppEndpoints.chatLinkPreview,
        queryParameters: {'url': url},
      );
      if (res.data['success'] == true && res.data['data'] != null) {
        if (mounted) {
          setState(() => _composeLinkPreview = {
                ...Map<String, dynamic>.from(
                    res.data['data'] as Map<String, dynamic>),
                'url': url,
              });
        }
      }
    } catch (_) {}
  }

  void _clear() {
    _isSending = true;
    _controller.clear();
    setState(() {
      _text = '';
      _replyingTo = null;
      _editingMessage = null;
      _composeLinkPreview = null;
    });
    Future.delayed(const Duration(milliseconds: 50),
        () => _isSending = false);
  }

  void _setText(String t) {
    _controller.text = t;
    setState(() => _text = t);
    // Move cursor to end
    _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: t.length));
  }

  void _setReplyTo(ChatMessage? msg) =>
      setState(() => _replyingTo = msg);
  void _setEditing(ChatMessage? msg) {
    setState(() => _editingMessage = msg);
    if (msg != null) {
      _setText(msg.content);
      _focusNode.requestFocus();
    }
  }

  void _clearReply() => setState(() => _replyingTo = null);
  void _clearEditing() {
    setState(() {
      _editingMessage = null;
      _text = '';
    });
    _controller.clear();
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply/Edit preview
        if (_replyingTo != null)
          _ReplyPreviewBar(
            message: _replyingTo!,
            currentUserId: widget.currentUserId,
            otherUserName: widget.otherUserName ?? 'User',
            onDismiss: _clearReply,
            c: c,
          ),
        if (_editingMessage != null)
          _EditPreviewBar(
            message: _editingMessage!,
            onDismiss: _clearEditing,
            c: c,
          ),

        // Link preview
        if (_composeLinkPreview != null &&
            _editingMessage == null)
          _ComposeLinkPreview(
            preview: _composeLinkPreview!,
            onDismiss: () =>
                setState(() => _composeLinkPreview = null),
            c: c,
          ),

        // Blocked / privacy banner
        if (widget.theyBlockedMe || widget.privacyBlocked)
          _BlockedBanner(
            theyBlockedMe: widget.theyBlockedMe,
            privacyBlocked: widget.privacyBlocked,
            privacyMessage: widget.privacyMessage,
            c: c,
          )
        // Incoming request actions
        else if (widget.isIncomingRequest)
          _RequestActions(
            otherUser: widget.otherUser,
            otherUserName: widget.otherUserName ?? 'User',
            isBlocked: widget.isBlocked,
            onAccept: widget.onAcceptRequest,
            onDelete: widget.onDeleteRequest,
            onBlock: widget.onBlockUnblock,
            c: c,
          )
        // Uploading
        else if (widget.uploadingMedia)
          _UploadingBanner(c: c)
        // Normal input
        else ...[
          // Outgoing request pending
          if (widget.isOutgoingRequest && widget.sentMessageCount >= 2)
            _PendingRequestBanner(
              otherUserName: widget.otherUserName ?? 'User',
              c: c,
            ),
          // Input row
          Container(
            padding: EdgeInsets.fromLTRB(
                8, 8, 8, bottomPad > 30 ? 16 : bottomPad + 8),
            decoration: BoxDecoration(
              color: c.background,
              border: Border(
                  top: BorderSide(
                      color: c.border.withOpacity(0.3),
                      width: 0.5)),
            ),
            child: Row(children: [
              // Input pill
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(children: [
                    // Emoji / sticker
                    IconButton(
                      icon: Icon(
                        _showEmoji
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: c.textSecondary,
                        size: 22,
                      ),
                      onPressed: _toggleEmoji,
                    ),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: TextStyle(
                            color: c.text,
                            fontFamily: 'Outfit',
                            fontSize: 15),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: widget.isGroup
                              ? 'Message'
                              : 'Message',
                          hintStyle: TextStyle(
                              color: c.textTertiary,
                              fontFamily: 'Outfit',
                              fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10),
                        ),
                      ),
                    ),
                    // Attachment
                    IconButton(
                      icon: Icon(Icons.attach_file,
                          color: c.textSecondary, size: 22),
                      onPressed: widget.onPickAndSendImage,
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              // Send / Mic button
              GestureDetector(
                onTap: _text.trim().isNotEmpty
                    ? widget.onSend
                    : (_editingMessage != null
                        ? () { _clearEditing(); }
                        : widget.onStartVoiceRecording),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _text.trim().isNotEmpty
                        ? Icons.send
                        : (_editingMessage != null
                            ? Icons.close
                            : Icons.mic),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ]),
          ),
        ],

        // Emoji picker
        if (_showEmoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                _controller.text += emoji.emoji;
              },
              config: Config(
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: c.surface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  indicatorColor: c.primary,
                  iconColor: c.textSecondary,
                  iconColorSelected: c.primary,
                  dividerColor: c.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sub-components ────────────────────────────────────────────────────────────

class _ReplyPreviewBar extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;
  final String otherUserName;
  final VoidCallback onDismiss;
  final ThemeColors c;

  const _ReplyPreviewBar({
    required this.message,
    required this.currentUserId,
    required this.otherUserName,
    required this.onDismiss,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.senderId == currentUserId;
    final senderName = isMe ? 'You' : otherUserName;

    String preview;
    switch (message.messageType) {
      case 'voice':
        preview = '🎤 Voice Message';
        break;
      case 'image':
        preview = '🌄 Photo';
        break;
      case 'video':
        preview = '🎥 Video';
        break;
      default:
        preview = message.content;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(children: [
        Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(senderName,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: c.primary)),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    color: c.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: c.textSecondary),
          onPressed: onDismiss,
        ),
      ]),
    );
  }
}

class _EditPreviewBar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onDismiss;
  final ThemeColors c;

  const _EditPreviewBar(
      {required this.message,
      required this.onDismiss,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(children: [
        Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editing Message',
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: c.primary)),
              Text(
                message.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    color: c.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: c.textSecondary),
          onPressed: onDismiss,
        ),
      ]),
    );
  }
}

class _ComposeLinkPreview extends StatelessWidget {
  final Map<String, dynamic> preview;
  final VoidCallback onDismiss;
  final ThemeColors c;

  const _ComposeLinkPreview(
      {required this.preview,
      required this.onDismiss,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(children: [
        Icon(Icons.link, size: 16, color: c.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview['url']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    color: c.primary),
              ),
              if (preview['title'] != null)
                Text(
                  preview['title'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: c.text),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 16, color: c.textSecondary),
          onPressed: onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  final bool theyBlockedMe;
  final bool privacyBlocked;
  final String? privacyMessage;
  final ThemeColors c;

  const _BlockedBanner({
    required this.theyBlockedMe,
    required this.privacyBlocked,
    required this.privacyMessage,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Icon(
          privacyBlocked ? Icons.lock : Icons.block,
          size: 18,
          color: privacyBlocked
              ? const Color(0xFFFF9F0A)
              : c.error,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            privacyBlocked
                ? (privacyMessage ??
                    'This user is not accepting messages')
                : 'You cannot message this user',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Outfit',
              color: privacyBlocked
                  ? const Color(0xFFFF9F0A)
                  : c.error,
            ),
          ),
        ),
      ]),
    );
  }
}

class _RequestActions extends StatelessWidget {
  final Map<String, dynamic>? otherUser;
  final String otherUserName;
  final bool isBlocked;
  final VoidCallback? onAccept;
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;
  final ThemeColors c;

  const _RequestActions({
    this.otherUser,
    required this.otherUserName,
    required this.isBlocked,
    this.onAccept,
    this.onDelete,
    this.onBlock,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(children: [
        Text(
          'Accept message request from $otherUserName?',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: c.text),
        ),
        const SizedBox(height: 4),
        Text(
          'If you accept, they will also be able to see info such as your activity status.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontFamily: 'Outfit',
              color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: onBlock,
            child: Text(isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(
                    color: c.error,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDelete,
            child: Text('Delete',
                style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: onAccept,
            child: const Text('Accept',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }
}

class _UploadingBanner extends StatelessWidget {
  final ThemeColors c;
  const _UploadingBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
            top: BorderSide(
                color: c.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: c.primary)),
        const SizedBox(width: 10),
        Text('Sending...',
            style: TextStyle(
                color: c.textSecondary, fontFamily: 'Outfit')),
      ]),
    );
  }
}

class _PendingRequestBanner extends StatelessWidget {
  final String otherUserName;
  final ThemeColors c;

  const _PendingRequestBanner(
      {required this.otherUserName, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.access_time, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Waiting for $otherUserName to accept your request',
            style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Outfit',
                color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

