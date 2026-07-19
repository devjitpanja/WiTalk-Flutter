import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  io.Socket? _socket;
  final List<Map<String, dynamic>> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _uid;
  Map<String, dynamic>? _groupInfo;
  bool _loading = true;
  bool _sending = false;
  bool _showEmoji = false;

  @override
  void initState() { super.initState(); _init(); }
  @override
  void dispose() { _socket?.disconnect(); _socket?.dispose(); _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance(); _uid = prefs.getString('uid');
    try {
      final msgs = await dioClient.get('/v1/groups/${widget.groupId}/messages');
      final info = await dioClient.get('/v1/groups/${widget.groupId}');
      setState(() { _messages.addAll(List<Map<String, dynamic>>.from(msgs.data['data'] ?? []).reversed); _groupInfo = info.data['data']; _loading = false; });
      _scrollToBottom();
    } catch (_) { setState(() => _loading = false); }
    _connectSocket();
  }

  void _connectSocket() async {
    final token = await const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)).read(key: 'accessToken');
    _socket = io.io(AppConfig.apiBaseUrl, io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build());
    _socket!.connect();
    _socket!.on('connect', (_) => _socket!.emit('join_group', {'groupId': widget.groupId, 'userId': _uid}));
    _socket!.on('new_group_message', (data) { if (mounted) { setState(() => _messages.add(Map<String, dynamic>.from(data))); _scrollToBottom(); } });
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut); });

  Future<void> _send() async {
    final text = _msgCtrl.text.trim(); if (text.isEmpty || _sending) return;
    _msgCtrl.clear(); setState(() => _sending = true);
    final temp = {'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 'content': text, 'sender_id': _uid, 'created_at': DateTime.now().toIso8601String(), 'is_sending': true};
    setState(() { _messages.add(temp); }); _scrollToBottom();
    try {
      final res = await dioClient.post('/v1/groups/${widget.groupId}/messages', data: {'content': text, 'type': 'text'});
      setState(() { final i = _messages.indexWhere((m) => m['id'] == temp['id']); if (i >= 0) _messages[i] = Map<String, dynamic>.from(res.data['data']); });
    } catch (_) { setState(() => _messages.removeWhere((m) => m['id'] == temp['id'])); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = _groupInfo?['name'] ?? 'Group';
    final pic = _groupInfo?['image'] ?? _groupInfo?['avatar'];
    final count = _groupInfo?['member_count'] ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        title: GestureDetector(onTap: () => context.push('/chat/group-info/${widget.groupId}'), child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)) : null),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            Text('$count members', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
          ]),
        ])),
        actions: [IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: () => context.push('/chat/group-info/${widget.groupId}'))]),
      body: Column(children: [
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: _messages.length, itemBuilder: (_, i) => _GroupBubble(message: _messages[i], uid: _uid ?? ''))),
        if (_showEmoji) SizedBox(height: 280, child: EmojiPicker(onEmojiSelected: (_, e) => _msgCtrl.text += e.emoji)),
        Container(padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))), child: Row(children: [
          IconButton(icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppColors.textTertiary), onPressed: () => setState(() => _showEmoji = !_showEmoji)),
          IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.textTertiary), onPressed: () {}),
          Expanded(child: TextField(controller: _msgCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'), maxLines: null, decoration: InputDecoration(hintText: 'Message...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
          const SizedBox(width: 6),
          GestureDetector(onTap: _send, child: Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.primaryButton, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 20))),
        ])),
      ]),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final Map<String, dynamic> message; final String uid;
  const _GroupBubble({required this.message, required this.uid});
  bool get _isMine => message['sender_id'] == uid;
  @override
  Widget build(BuildContext context) {
    final sender = message['sender'] as Map<String, dynamic>?;
    final senderName = sender?['name'] ?? '';
    final senderPic = sender?['profile_pic'];
    final time = message['created_at'] != null ? timeago.format(DateTime.tryParse(message['created_at']) ?? DateTime.now(), allowFromNow: true) : '';
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: _isMine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
      if (!_isMine) ...[
        CircleAvatar(radius: 14, backgroundColor: AppColors.border, backgroundImage: senderPic != null ? CachedNetworkImageProvider(senderPic) : null, child: senderPic == null ? Text((senderName.isNotEmpty ? senderName[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)) : null),
        const SizedBox(width: 6),
      ],
      Flexible(child: Column(crossAxisAlignment: _isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (!_isMine) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(senderName, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w600))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: _isMine ? AppColors.primaryButton : AppColors.surface, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(_isMine ? 16 : 4), bottomRight: Radius.circular(_isMine ? 4 : 16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(message['content'] ?? '', style: TextStyle(color: _isMine ? Colors.white : AppColors.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Outfit')),
          ])),
      ])),
    ]));
  }
}
