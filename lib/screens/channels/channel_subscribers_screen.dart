import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ChannelSubscribersScreen extends StatefulWidget {
  final String channelId;
  final int initialSubscriberCount;
  final bool isOwner;
  final bool isAdmin;

  const ChannelSubscribersScreen({
    super.key,
    required this.channelId,
    this.initialSubscriberCount = 0,
    this.isOwner = false,
    this.isAdmin = false,
  });

  @override
  State<ChannelSubscribersScreen> createState() => _ChannelSubscribersScreenState();
}

class _ChannelSubscribersScreenState extends State<ChannelSubscribersScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _subscribers = [];
  Set<String> _ownerIds = {};
  Set<String> _adminIds = {};
  String? _myUserId;

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
    _total = widget.initialSubscriberCount;
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final uid = await _storage.read(key: 'uid');
    if (mounted) setState(() => _myUserId = uid);

    try {
      final adminsRes = await ChannelApi.getAdmins(widget.channelId);
      final adminsList = List<Map<String, dynamic>>.from(adminsRes.data?['admins'] ?? []);
      if (mounted) {
        setState(() {
          _ownerIds = adminsList
              .where((a) => a['role'] == 'owner')
              .map((a) => a['id']?.toString() ?? '')
              .toSet();
          _adminIds = adminsList
              .where((a) => a['role'] == 'admin')
              .map((a) => a['id']?.toString() ?? '')
              .toSet();
        });
      }
    } catch (_) {}

    _fetchSubscribers(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _fetchSubscribers(reset: false);
      }
    }
  }

  Future<void> _fetchSubscribers({bool reset = false}) async {
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
      final res = await ChannelApi.getSubscribers(
        widget.channelId,
        params: {
          'limit': 30,
          'offset': reset ? 0 : _offset,
          if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim(),
        },
      );

      final list = List<Map<String, dynamic>>.from(res.data?['subscribers'] ?? []);
      final tot = (res.data?['total'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _total = tot;
          if (reset) {
            _subscribers = list;
          } else {
            _subscribers.addAll(list);
          }
          _offset = _subscribers.length;
          _hasMore = _subscribers.length < tot;
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
      _fetchSubscribers(reset: true);
    });
  }

  void _showActionModal(Map<String, dynamic> subscriber) {
    final colors = context.colors;
    final String subId = subscriber['id']?.toString() ?? '';
    final String subName = subscriber['name']?.toString() ?? 'User';

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subName,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isOwner)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF3B82F6)),
                  title: Text('Make Admin', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _makeAdmin(subId, subName);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: Text('Remove from Channel', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeSubscriber(subId, subName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text('Ban User', style: TextStyle(fontFamily: 'Outfit', color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _banSubscriber(subId, subName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeAdmin(String userId, String name) async {
    try {
      await ChannelApi.makeSubscriberAdmin(widget.channelId, userId);
      setState(() => _adminIds.add(userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is now an admin')),
        );
      }
    } catch (_) {
      _showAlert('Error', 'Could not make $name an admin');
    }
  }

  Future<void> _removeSubscriber(String userId, String name) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Remove Subscriber', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
        content: Text('Remove $name from this channel? They can rejoin later.',
            style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.kickSubscriber(widget.channelId, userId);
        setState(() {
          _subscribers.removeWhere((s) => s['id']?.toString() == userId);
          _total = (_total - 1).clamp(0, 9999999);
        });
      } catch (_) {
        _showAlert('Error', 'Could not remove subscriber');
      }
    }
  }

  Future<void> _banSubscriber(String userId, String name) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Ban User', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
        content: Text('Ban $name from this channel? They will be removed and blocked from rejoining.',
            style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.banSubscriber(widget.channelId, userId, 'Banned by admin');
        setState(() {
          _subscribers.removeWhere((s) => s['id']?.toString() == userId);
          _total = (_total - 1).clamp(0, 9999999);
        });
      } catch (_) {
        _showAlert('Error', 'Could not ban user');
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
    final canManage = widget.isOwner || widget.isAdmin;

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
                  hintText: 'Search subscribers...',
                  hintStyle: TextStyle(fontFamily: 'Outfit', color: colors.placeholder),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscribers',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
                  ),
                  Text(
                    '$_total subscriber${_total == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary),
                  ),
                ],
              ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, color: colors.text),
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
          : _subscribers.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No matching subscribers' : 'No subscribers yet',
                    style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _subscribers.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(height: 1, color: colors.border.withOpacity(0.15)),
                  itemBuilder: (context, index) {
                    if (index == _subscribers.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(color: colors.primary)),
                      );
                    }

                    final sub = _subscribers[index];
                    final String subId = sub['id']?.toString() ?? '';
                    final String name = sub['name']?.toString() ?? 'User';
                    final String username = sub['username']?.toString() ?? '';
                    final String? pic = sub['profile_pic']?.toString();

                    final bool isMe = subId == _myUserId;
                    final bool isOwner = _ownerIds.contains(subId);
                    final bool isAdmin = _adminIds.contains(subId);

                    final bool showMenu = canManage && !isMe && !isAdmin && !isOwner;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primary,
                        backgroundImage: pic != null && pic.isNotEmpty ? NetworkImage(pic) : null,
                        child: pic == null || pic.isEmpty
                            ? Text(
                                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: colors.text),
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Owner', style: TextStyle(fontSize: 10, fontFamily: 'Outfit', color: Colors.white)),
                            ),
                          ] else if (isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Admin', style: TextStyle(fontSize: 10, fontFamily: 'Outfit', color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('@$username', style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary)),
                      trailing: showMenu
                          ? IconButton(
                              icon: Icon(Icons.more_vert, color: colors.textSecondary),
                              onPressed: () => _showActionModal(sub),
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
