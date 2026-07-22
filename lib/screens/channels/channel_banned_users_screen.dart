import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ChannelBannedUsersScreen extends StatefulWidget {
  final String channelId;

  const ChannelBannedUsersScreen({
    super.key,
    required this.channelId,
  });

  @override
  State<ChannelBannedUsersScreen> createState() => _ChannelBannedUsersScreenState();
}

class _ChannelBannedUsersScreenState extends State<ChannelBannedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _bannedUsers = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  int _offset = 0;
  String _searchQuery = '';
  bool _showSearch = false;

  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchBannedUsers(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _fetchBannedUsers(reset: false);
      }
    }
  }

  Future<void> _fetchBannedUsers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await ChannelApi.getBannedUsers(
        widget.channelId,
        params: {
          'limit': 30,
          'offset': reset ? 0 : _offset,
          if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim(),
        },
      );

      final list = List<Map<String, dynamic>>.from(res.data?['banned_users'] ?? []);
      final tot = (res.data?['total'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _total = tot;
          if (reset) {
            _bannedUsers = list;
          } else {
            _bannedUsers.addAll(list);
          }
          _offset = _bannedUsers.length;
          _hasMore = _bannedUsers.length < tot;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String text) {
    setState(() => _searchQuery = text);
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchBannedUsers(reset: true);
    });
  }

  Future<void> _handleUnban(Map<String, dynamic> user) async {
    final colors = context.colors;
    final String userId = user['user_id']?.toString() ?? user['id']?.toString() ?? '';
    final String name = user['name']?.toString() ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Unban User', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
        content: Text('Allow $name to rejoin this channel?',
            style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unban', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.unbanUser(widget.channelId, userId);
        setState(() {
          _bannedUsers.removeWhere((u) => (u['user_id']?.toString() ?? u['id']?.toString()) == userId);
          _total = (_total - 1).clamp(0, 999999);
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not unban user')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontFamily: 'Outfit', color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Search banned users...',
                  hintStyle: TextStyle(fontFamily: 'Outfit', color: colors.placeholder),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(
                'Banned Users',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
              ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, color: colors.primary),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _onSearchChanged('');
                }
              });
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Banned users cannot rejoin this channel. Unban to allow them back.',
                        style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary),
                      ),
                      if (_bannedUsers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '$_total BANNED USER${_total == 1 ? '' : 'S'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: colors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_bannedUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.how_to_reg, size: 48, color: colors.border),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No results found' : 'No banned users',
                          style: TextStyle(fontFamily: 'Outfit', color: colors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else
                  ..._bannedUsers.map((item) {
                    final String name = item['name']?.toString() ?? 'User';
                    final String username = item['username']?.toString() ?? '';
                    final String? pic = item['profile_pic']?.toString();
                    final String? reason = item['reason']?.toString();

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: colors.primary,
                            backgroundImage: pic != null && pic.isNotEmpty ? NetworkImage(pic) : null,
                            child: pic == null || pic.isEmpty
                                ? Text(
                                    (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@$username',
                                  style: TextStyle(
                                      fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary)),
                              if (reason != null && reason.isNotEmpty)
                                Text('Reason: $reason',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Outfit', color: colors.textTertiary)),
                            ],
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.lock_open, size: 18, color: colors.success),
                              onPressed: () => _handleUnban(item),
                            ),
                          ),
                        ),
                        Divider(height: 1, indent: 80, color: colors.border.withOpacity(0.15)),
                      ],
                    );
                  }),
                if (_loadingMore)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(color: colors.primary)),
                  ),
              ],
            ),
    );
  }
}
