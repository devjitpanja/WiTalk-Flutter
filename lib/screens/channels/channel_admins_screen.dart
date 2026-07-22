import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

class ChannelAdminsScreen extends StatefulWidget {
  final String channelId;
  final bool isOwner;

  const ChannelAdminsScreen({
    super.key,
    required this.channelId,
    this.isOwner = false,
  });

  @override
  State<ChannelAdminsScreen> createState() => _ChannelAdminsScreenState();
}

class _ChannelAdminsScreenState extends State<ChannelAdminsScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final uid = await _storage.read(key: 'uid');
    if (mounted) setState(() => _myUserId = uid);
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    try {
      final res = await ChannelApi.getAdmins(widget.channelId);
      final list = List<Map<String, dynamic>>.from(res.data?['admins'] ?? []);
      if (mounted) {
        setState(() {
          _admins = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRemoveAdmin(Map<String, dynamic> admin) async {
    final colors = context.colors;
    final String adminId = admin['id']?.toString() ?? '';
    final String username = admin['username']?.toString() ?? 'admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Remove Admin', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
        content: Text('Remove @$username as admin?',
            style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.removeAdmin(widget.channelId, adminId);
        setState(() {
          _admins.removeWhere((a) => a['id']?.toString() == adminId);
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not remove admin')),
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
        title: Text(
          'Administrators',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
                  child: Text(
                    'ADMINISTRATORS — ${_admins.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (_admins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 48, color: colors.border),
                        const SizedBox(height: 12),
                        Text(
                          'No administrators found',
                          style: TextStyle(fontFamily: 'Outfit', color: colors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else
                  ..._admins.map((item) {
                    final String adminId = item['id']?.toString() ?? '';
                    final String name = item['name']?.toString() ?? 'User';
                    final String username = item['username']?.toString() ?? '';
                    final String? pic = item['profile_pic']?.toString();
                    final String role = item['role']?.toString() ?? 'admin';

                    final bool isCurrentUser = adminId == _myUserId;
                    final bool isOwnerItem = role == 'owner';

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
                          subtitle: Text(
                            '@$username',
                            style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOwnerItem ? Colors.red : colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isOwnerItem ? 'Owner' : 'Admin',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (widget.isOwner && !isOwnerItem && !isCurrentUser) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: colors.textTertiary),
                                  onPressed: () => _handleRemoveAdmin(item),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Divider(height: 1, indent: 80, color: colors.border.withOpacity(0.15)),
                      ],
                    );
                  }),
              ],
            ),
    );
  }
}
