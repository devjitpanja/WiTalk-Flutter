import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  List<Map<String, dynamic>> _channels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final res = await ChannelApi.getMy();
      final list = List<Map<String, dynamic>>.from(res.data?['channels'] ?? []);
      if (mounted) {
        setState(() {
          _channels = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openExplore() {
    context.push('/explore-channels');
  }

  void _openChannel(Map<String, dynamic> channel) {
    final String channelId = channel['id']?.toString() ?? '';
    context.push('/channel/$channelId', extra: {'channel': channel});
  }

  String _getLastMessageText(Map<String, dynamic> channel) {
    if (channel['last_message_at'] == null) return 'No updates yet';
    final type = channel['last_message_type']?.toString();
    if (type == 'image') return '📷 Photo';
    if (type == 'image_album') return '📷 Album';
    if (type == 'video') return '🎥 Video';
    if (type == 'voice') return '🎤 Voice Message';
    if (type == 'audio') return '🎵 Audio';
    if (type == 'file') return '📄 File';
    if (type == 'giphy_gif') return '🎞 GIF';
    if (type == 'giphy_sticker') return '🎭 Sticker';
    if (type == 'poll') return '📊 Poll';
    return channel['last_message']?.toString() ?? 'New update';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (_channels.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: colors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'No Channels Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to channels to get updates from people and topics you care about',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _openExplore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Explore Channels',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Channels',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.explore, color: colors.primary),
            onPressed: _openExplore,
          ),
        ],
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _loadChannels,
          ),
          SliverList.separated(
            itemCount: _channels.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 80, color: colors.border.withOpacity(0.15)),
            itemBuilder: (context, index) {
              final item = _channels[index];
              final name = item['name']?.toString() ?? 'Channel';
              final iconUrl = item['icon']?.toString();
              final isBanned = (item['is_banned'] == 1 || item['is_banned'] == true);
              final isVerified = (item['is_verified'] == 1 || item['is_verified'] == true);
              final unreadCount = (item['unread_count'] as num?)?.toInt() ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isBanned ? Colors.grey : colors.primary,
                      backgroundImage: iconUrl != null && iconUrl.isNotEmpty ? NetworkImage(iconUrl) : null,
                      child: iconUrl == null || iconUrl.isEmpty
                          ? Text(
                              (name.isNotEmpty ? name[0] : 'C').toUpperCase(),
                              style: const TextStyle(fontSize: 22, color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (isBanned)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.4),
                          ),
                          child: const Icon(Icons.gavel, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: isBanned ? colors.textSecondary : colors.text,
                        ),
                      ),
                    ),
                    if (!isBanned && isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Color(0xFF0751DF)),
                    ],
                  ],
                ),
                subtitle: Text(
                  isBanned ? 'This channel has been banned by the platform' : _getLastMessageText(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontStyle: isBanned ? FontStyle.italic : FontStyle.normal,
                    color: isBanned ? Colors.red : colors.textSecondary,
                  ),
                ),
                trailing: unreadCount > 0 && !isBanned
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    : null,
                onTap: () => _openChannel(item),
              );
            },
          ),
        ],
      ),
    );
  }
}
