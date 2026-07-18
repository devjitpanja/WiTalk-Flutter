import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _channelMsgsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  final res = await dioClient.get('/v1/channels/$id/messages');
  return res.data['data'] ?? [];
});

class ChannelScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});
  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  Map<String, dynamic>? _channel;
  bool _isAdmin = false;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() { super.initState(); _loadChannel(); }
  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _loadChannel() async {
    try { final res = await dioClient.get('/v1/channels/${widget.channelId}'); if (mounted) setState(() { _channel = res.data['data']; _isAdmin = res.data['data']?['is_admin'] == true; }); } catch (_) {}
  }

  Future<void> _sendMsg() async {
    final text = _msgCtrl.text.trim(); if (text.isEmpty || _sending) return;
    setState(() => _sending = true); _msgCtrl.clear();
    try { await dioClient.post('/v1/channels/${widget.channelId}/messages', data: {'content': text}); ref.refresh(_channelMsgsProvider(widget.channelId)); } catch (_) {}
    finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = _channel?['name'] ?? 'Channel';
    final pic = _channel?['image'];
    final subs = _channel?['subscriber_count'] ?? 0;
    final msgsAsync = ref.watch(_channelMsgsProvider(widget.channelId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        title: GestureDetector(onTap: () => context.push('/channel-info/${widget.channelId}'), child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? const Icon(Icons.campaign, color: Colors.white, size: 18) : null),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            Text('$subs subscribers', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
          ]),
        ])),
        actions: [IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: () => context.push('/channel-info/${widget.channelId}'))]),
      body: Column(children: [
        Expanded(child: msgsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
          error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
          data: (msgs) => ListView.builder(reverse: true, padding: const EdgeInsets.all(12), itemCount: msgs.length,
            itemBuilder: (_, i) { final m = msgs[i] as Map<String, dynamic>; return _ChannelBroadcast(message: m); }),
        )),
        if (_isAdmin) Container(padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
          child: Row(children: [
            Expanded(child: TextField(controller: _msgCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'), decoration: InputDecoration(hintText: 'Broadcast a message...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'), filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            GestureDetector(onTap: _sendMsg, child: Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.primaryButton, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 20))),
          ])),
      ]),
    );
  }
}

class _ChannelBroadcast extends StatelessWidget {
  final Map<String, dynamic> message;
  const _ChannelBroadcast({required this.message});
  @override
  Widget build(BuildContext context) {
    final time = message['created_at'] != null ? timeago.format(DateTime.tryParse(message['created_at']) ?? DateTime.now()) : '';
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message['content'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontFamily: 'Outfit', height: 1.4)),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
      ]));
  }
}
