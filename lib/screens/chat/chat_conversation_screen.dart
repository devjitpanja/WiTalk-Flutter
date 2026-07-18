import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatConversationScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  io.Socket? _socket;
  final List<Map<String, dynamic>> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _uid;
  Map<String, dynamic>? _chatPartner;
  bool _loading = true;
  bool _sending = false;
  bool _showEmoji = false;
  bool _isTyping = false;
  bool _partnerTyping = false;

  @override
  void initState() {
    super.initState();
    _init();
    _msgCtrl.addListener(_onTyping);
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    await _loadMessages();
    _connectSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await dioClient.get('/v1/chat/${widget.chatId}/messages');
      final msgs = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      final partnerRes = await dioClient.get('/v1/chat/${widget.chatId}/info');
      setState(() {
        _messages.addAll(msgs.reversed);
        _chatPartner = partnerRes.data['data'];
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _connectSocket() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    _socket = io.io(AppConfig.apiBaseUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .disableAutoConnect()
        .build());

    _socket!.connect();

    _socket!.on('connect', (_) {
      _socket!.emit('join_chat', {'chatId': widget.chatId, 'userId': _uid});
    });

    _socket!.on('new_message', (data) {
      if (mounted) {
        setState(() => _messages.add(Map<String, dynamic>.from(data)));
        _scrollToBottom();
      }
    });

    _socket!.on('typing', (data) {
      if (data['userId'] != _uid && mounted) setState(() => _partnerTyping = data['isTyping'] == true);
    });

    _socket!.on('message_read', (data) {
      if (mounted) setState(() {
        for (final msg in _messages) {
          if (msg['id'] == data['messageId']) msg['is_read'] = true;
        }
      });
    });
  }

  void _onTyping() {
    final typing = _msgCtrl.text.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _socket?.emit('typing', {'chatId': widget.chatId, 'userId': _uid, 'isTyping': typing});
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);

    final tempMsg = {'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 'content': text, 'sender_id': _uid, 'created_at': DateTime.now().toIso8601String(), 'is_sending': true};
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      final res = await dioClient.post('/v1/chat/${widget.chatId}/messages', data: {'content': text, 'type': 'text'});
      final saved = Map<String, dynamic>.from(res.data['data']);
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == tempMsg['id']);
        if (idx >= 0) _messages[idx] = saved;
      });
    } catch (_) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempMsg['id']));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      final formData = {'file': await dioClient.options.baseUrl};
      await dioClient.post('/v1/chat/${widget.chatId}/messages', data: {'type': 'image', 'filePath': picked.path});
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _chatPartner?['name'] ?? 'Chat';
    final pic = _chatPartner?['profile_pic'];
    final isOnline = _chatPartner?['is_online'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        title: GestureDetector(
          onTap: () => context.push('/user/${_chatPartner?['id']}'),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.border,
                backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)) : null),
              if (isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 1.5)))),
            ]),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              Text(_partnerTyping ? 'typing...' : isOnline ? 'Online' : 'Offline',
                style: TextStyle(color: _partnerTyping ? AppColors.success : AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
            ]),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () => context.push('/video-call/${widget.chatId}')),
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () => context.push('/voice-call/${widget.chatId}')),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: _messages[i], uid: _uid ?? ''),
              ),
        ),
        if (_partnerTyping)
          const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(children: [Text('typing...', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Outfit'))])),
        if (_showEmoji) SizedBox(height: 280, child: EmojiPicker(
          onEmojiSelected: (_, emoji) => _msgCtrl.text += emoji.emoji,
        )),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5)), color: AppColors.background),
    child: Row(children: [
      IconButton(icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppColors.textTertiary),
        onPressed: () => setState(() => _showEmoji = !_showEmoji)),
      IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.textTertiary), onPressed: _sendImage),
      Expanded(child: TextField(
        controller: _msgCtrl,
        style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        maxLines: null,
        decoration: InputDecoration(
          hintText: 'Type a message...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
          filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _sendMessage(),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _sendMessage,
        child: Container(width: 42, height: 42,
          decoration: const BoxDecoration(color: AppColors.primaryButton, shape: BoxShape.circle),
          child: const Icon(Icons.send, color: Colors.white, size: 20)),
      ),
    ]),
  );
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String uid;
  const _MessageBubble({required this.message, required this.uid});

  bool get _isMine => message['sender_id'] == uid;
  String get _content => message['content'] ?? '';
  String? get _imageUrl => message['image_url'] ?? message['media_url'];
  bool get _isSending => message['is_sending'] == true;
  bool get _isRead => message['is_read'] == true;
  String get _time => message['created_at'] != null ? timeago.format(DateTime.tryParse(message['created_at']) ?? DateTime.now(), allowFromNow: true) : '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: _isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!_isMine) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              padding: _imageUrl != null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isMine ? AppColors.primaryButton : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(_isMine ? 18 : 4),
                  bottomRight: Radius.circular(_isMine ? 4 : 18),
                ),
              ),
              child: Column(crossAxisAlignment: _isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                if (_imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(imageUrl: _imageUrl!, width: 200, height: 200, fit: BoxFit.cover)),
                if (_content.isNotEmpty)
                  Text(_content, style: TextStyle(color: _isMine ? Colors.white : AppColors.textSecondary, fontSize: 15, fontFamily: 'Outfit')),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_time, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Outfit')),
                  if (_isMine) ...[
                    const SizedBox(width: 4),
                    _isSending
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54))
                        : Icon(_isRead ? Icons.done_all : Icons.done, size: 14, color: _isRead ? Colors.blue.shade300 : Colors.white54),
                  ],
                ]),
              ]),
            ),
          ),
          if (_isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
