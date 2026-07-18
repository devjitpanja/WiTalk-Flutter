import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class ChannelInfoScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChannelInfoScreen({super.key, required this.channelId});
  @override
  ConsumerState<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends ConsumerState<ChannelInfoScreen> {
  Map<String, dynamic>? _channel;
  bool _loading = true, _subscribed = false, _toggling = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await dioClient.get('/v1/channels/${widget.channelId}');
      setState(() { _channel = res.data['data']; _subscribed = res.data['data']?['is_subscribed'] == true; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _toggle() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      await dioClient.post('/v1/channels/${widget.channelId}/${_subscribed ? 'unsubscribe' : 'subscribe'}');
      setState(() => _subscribed = !_subscribed);
    } catch (_) {} finally { if (mounted) setState(() => _toggling = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = _channel?['name'] as String? ?? '';
    final desc = _channel?['description'] as String? ?? '';
    final pic = _channel?['image'] as String?;
    final subs = _channel?['subscriber_count'] ?? 0;
    final admins = (_channel?['admins'] as List? ?? []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Channel Info', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 48, backgroundColor: AppColors.border,
          backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
          child: pic == null ? const Icon(Icons.campaign, color: Colors.white, size: 40) : null),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        const SizedBox(height: 4),
        Text('$subs subscribers', style: const TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
        if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontFamily: 'Outfit', height: 1.5), textAlign: TextAlign.center)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _toggling ? null : _toggle,
          style: ElevatedButton.styleFrom(backgroundColor: _subscribed ? AppColors.border : AppColors.primaryButton, minimumSize: const Size(200, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          child: _toggling ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_subscribed ? 'Unsubscribe' : 'Subscribe', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        if (admins.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text('Admins', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit', letterSpacing: 0.8))),
          const SizedBox(height: 8),
          ...admins.map((a) {
            final admin = a as Map<String, dynamic>;
            final aName = admin['name'] as String? ?? '';
            final aPic = admin['profile_pic'] as String?;
            final aId = admin['id'] as String? ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 20, backgroundColor: AppColors.border, backgroundImage: aPic != null ? CachedNetworkImageProvider(aPic) : null, child: aPic == null ? Text(aName.isNotEmpty ? aName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
              title: Text(aName, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
              onTap: () => context.push('/user/$aId'),
            );
          }),
        ],
      ])),
    );
  }
}
