import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ChannelInfoScreen extends StatefulWidget {
  final String channelId;

  const ChannelInfoScreen({
    super.key,
    required this.channelId,
  });

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  late TabController _tabController;

  Map<String, dynamic>? _channel;
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  String? _myUserId;
  bool _muted = false;

  List<Map<String, dynamic>> _mediaItems = [];
  bool _mediaLoading = false;
  bool _mediaLoaded = false;

  List<Map<String, dynamic>> _linkItems = [];
  bool _linksLoading = false;
  bool _linksLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0 && !_mediaLoaded) {
        _fetchMedia();
      } else if (_tabController.index == 1 && !_linksLoaded) {
        _fetchLinks();
      }
    });
    _fetchChannelInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChannelInfo() async {
    final uid = await _storage.read(key: 'uid');
    if (mounted) setState(() => _myUserId = uid);

    try {
      final res = await ChannelApi.getById(widget.channelId);
      final adminsRes = await ChannelApi.getAdmins(widget.channelId);
      final data = res.data?['channel'];
      final adminsList = List<Map<String, dynamic>>.from(adminsRes.data?['admins'] ?? []);

      if (data != null && mounted) {
        setState(() {
          _channel = data;
          _admins = adminsList;
          _muted = data['is_muted'] == 1 || data['is_muted'] == true;
          _loading = false;
        });
        _fetchMedia();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMedia() async {
    if (_mediaLoading || _mediaLoaded) return;
    setState(() => _mediaLoading = true);
    try {
      final res = await ChannelApi.getMedia(widget.channelId);
      final list = List<Map<String, dynamic>>.from(res.data?['media'] ?? []);
      if (mounted) {
        setState(() {
          _mediaItems = list;
          _mediaLoaded = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _mediaLoading = false);
    }
  }

  Future<void> _fetchLinks() async {
    if (_linksLoading || _linksLoaded) return;
    setState(() => _linksLoading = true);
    try {
      final res = await ChannelApi.getLinks(widget.channelId);
      final list = List<Map<String, dynamic>>.from(res.data?['links'] ?? []);
      if (mounted) {
        setState(() {
          _linkItems = list;
          _linksLoaded = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _linksLoading = false);
    }
  }

  bool get _isAdmin {
    final role = _channel?['my_role']?.toString();
    return role == 'owner' || role == 'admin';
  }

  bool get _isOwner => _channel?['my_role']?.toString() == 'owner';

  String? get _shareLink {
    if (_channel == null) return null;
    final type = _channel!['channel_type']?.toString();
    final username = _channel!['username']?.toString();
    final inviteCode = _channel!['invite_code']?.toString();

    if (type == 'public' && username != null && username.isNotEmpty) {
      return 'https://witalk.in/$username';
    }
    if (type == 'private' && inviteCode != null && inviteCode.isNotEmpty) {
      return 'https://witalk.in/invite/$inviteCode';
    }
    return null;
  }

  Future<void> _toggleMute() async {
    try {
      if (_muted) {
        await ChannelApi.unmute(widget.channelId);
      } else {
        await ChannelApi.mute(widget.channelId);
      }
      setState(() => _muted = !_muted);
    } catch (_) {
      _showAlert('Error', 'Could not update notification settings');
    }
  }

  void _copyShareLink() {
    if (_shareLink != null) {
      Clipboard.setData(ClipboardData(text: _shareLink!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  Future<void> _leaveChannel() async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Leave Channel?', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
        content: Text('Are you sure you want to leave this channel?',
            style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.unsubscribe(widget.channelId);
        if (mounted) context.go('/channels');
      } catch (_) {
        _showAlert('Error', 'Could not leave channel');
      }
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
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

    final name = _channel?['name']?.toString() ?? 'Channel';
    final desc = _channel?['description']?.toString();
    final iconUrl = _channel?['icon']?.toString();
    final username = _channel?['username']?.toString();
    final isVerified = (_channel?['is_verified'] == 1 || _channel?['is_verified'] == true);
    final subscriberCount = (_channel?['subscriber_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar Header
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => context.push(
                    '/edit-channel/${widget.channelId}',
                    extra: {'channel': _channel},
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 2),
                            image: iconUrl != null && iconUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage(iconUrl), fit: BoxFit.cover)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: iconUrl == null || iconUrl.isEmpty
                              ? Text(
                                  (name.isNotEmpty ? name[0] : 'C').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 16, color: Colors.white),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$subscriberCount subscribers',
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Info Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildHeaderActionButton(
                        icon: _muted ? Icons.notifications_off : Icons.notifications,
                        label: _muted ? 'Unmute' : 'Mute',
                        colors: colors,
                        onTap: _toggleMute,
                      ),
                      if (_shareLink != null)
                        _buildHeaderActionButton(
                          icon: Icons.share,
                          label: 'Share',
                          colors: colors,
                          onTap: _copyShareLink,
                        ),
                      if (_isAdmin)
                        _buildHeaderActionButton(
                          icon: Icons.settings,
                          label: 'Edit',
                          colors: colors,
                          onTap: () => context.push('/edit-channel/${widget.channelId}',
                              extra: {'channel': _channel}),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Handle & Description
                  if (username != null && username.isNotEmpty) ...[
                    Text(
                      'HANDLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: colors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (desc != null && desc.isNotEmpty) ...[
                    Text(
                      'ABOUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: colors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Outfit',
                        color: colors.text,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Management Section (Admins/Owner only)
                  if (_isAdmin) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.people, color: colors.primary),
                            title: Text('Subscribers', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$subscriberCount',
                                    style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                            onTap: () => context.push(
                              '/channel-subscribers/${widget.channelId}',
                              extra: {
                                'subscriberCount': subscriberCount,
                                'isOwner': _isOwner,
                                'isAdmin': _isAdmin,
                              },
                            ),
                          ),
                          Divider(height: 1, color: colors.border.withOpacity(0.3)),
                          ListTile(
                            leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF3B82F6)),
                            title: Text('Administrators', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${_admins.length}',
                                    style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                            onTap: () => context.push(
                              '/channel-admins/${widget.channelId}',
                              extra: {'isOwner': _isOwner},
                            ),
                          ),
                          Divider(height: 1, color: colors.border.withOpacity(0.3)),
                          ListTile(
                            leading: const Icon(Icons.block, color: Colors.red),
                            title: Text('Banned Users', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => context.push('/channel-banned-users/${widget.channelId}'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Media & Links Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: colors.primary,
                    tabs: const [
                      Tab(text: 'Media'),
                      Tab(text: 'Links'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Media Tab
                        _mediaLoading
                            ? Center(child: CircularProgressIndicator(color: colors.primary))
                            : _mediaItems.isEmpty
                                ? Center(
                                    child: Text(
                                      'No media shared yet',
                                      style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary),
                                    ),
                                  )
                                : GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4,
                                    ),
                                    itemCount: _mediaItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _mediaItems[index];
                                      final url = item['media_url']?.toString() ?? '';
                                      return Image.network(url, fit: BoxFit.cover);
                                    },
                                  ),

                        // Links Tab
                        _linksLoading
                            ? Center(child: CircularProgressIndicator(color: colors.primary))
                            : _linkItems.isEmpty
                                ? Center(
                                    child: Text(
                                      'No links shared yet',
                                      style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _linkItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _linkItems[index];
                                      final url = item['url']?.toString() ?? '';
                                      return ListTile(
                                        leading: Icon(Icons.link, color: colors.primary),
                                        title: Text(
                                          url,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontFamily: 'Outfit', color: colors.primary),
                                        ),
                                        onTap: () => Clipboard.setData(ClipboardData(text: url)),
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Leave Channel Button
                  if (!_isOwner)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _leaveChannel,
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        label: const Text('Leave Channel',
                            style: TextStyle(fontFamily: 'Outfit', color: Colors.red, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required ThemeColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: Icon(icon, color: colors.primary, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
