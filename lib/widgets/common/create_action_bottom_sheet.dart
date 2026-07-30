import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../theme/theme_colors.dart';
import '../../theme/app_colors.dart';

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showCreateActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => const _CreateActionSheet(),
  );
}

// ── Feature flag model ────────────────────────────────────────────────────────

class _Flags {
  final bool createPost;
  final bool createCommunity;
  final bool createChannel;
  const _Flags({
    this.createPost = true,
    this.createCommunity = false,
    this.createChannel = false,
  });
  factory _Flags.fromJson(Map<String, dynamic> j) => _Flags(
        createPost: j['create_post_enabled'] ?? true,
        createCommunity: j['create_community_enabled'] ?? false,
        createChannel: j['create_channel_enabled'] ?? false,
      );
}

// ── Bottom sheet widget ───────────────────────────────────────────────────────

class _CreateActionSheet extends ConsumerStatefulWidget {
  const _CreateActionSheet();
  @override
  ConsumerState<_CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends ConsumerState<_CreateActionSheet> {
  _Flags _flags = const _Flags();
  bool _isProfessional = false;
  bool _isVerified = false;
  bool _loading = true;
  bool _processingPost = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    debugPrint('[CreateSheet] uid=$_uid');
    await Future.wait([_loadFlags(), if (_uid != null) _loadUserInfo()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFlags() async {
    try {
      final res = await dioClient.get('/v1/config/create-actions');
      final data = res.data?['data'];
      debugPrint('[CreateSheet] flags=$data');
      if (data != null && mounted) {
        setState(() => _flags = _Flags.fromJson(data as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('[CreateSheet] flags error: $e — using defaults');
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final res = await dioClient.get('/v1/user/$_uid');
      final data = res.data?['data'];
      debugPrint('[CreateSheet] userInfo account_type=${data?['account_type']} is_verified=${data?['is_verified']}');
      if (data != null && mounted) {
        setState(() {
          _isProfessional = (data['account_type'] as String?) == 'professional';
          _isVerified = data['is_verified'] == true;
        });
      }
    } catch (e) {
      debugPrint('[CreateSheet] userInfo error: $e');
    }
  }

  // ── Create Post ─────────────────────────────────────────────────────────────
  // All async work happens WHILE the sheet is still open so `mounted` stays
  // true and `context` remains valid. We only close + navigate at the very end.

  Future<void> _handleCreatePost() async {
    if (!mounted || _processingPost) return;
    setState(() => _processingPost = true);
    debugPrint('[CreateSheet] handleCreatePost start');

    // 1. Post rate-limit check
    if (_uid != null) {
      try {
        final res = await dioClient.get('/v1/config/post-limit/$_uid');
        final data = res.data?['data'];
        debugPrint('[CreateSheet] post-limit data=$data');
        if (data != null && data['can_post'] == false) {
          if (!mounted) return;
          final limit = data['daily_limit'] ?? 5;
          final isVerified = data['is_verified'] == true;
          final hint = isVerified
              ? 'You\'ve reached your daily limit of $limit posts.'
              : 'You\'ve reached your daily limit of $limit posts. Get verified to post up to 15 times a day!';
          setState(() => _processingPost = false);
          _showInfoDialog('Daily Limit Reached', hint);
          return;
        }
      } catch (e) {
        debugPrint('[CreateSheet] post-limit error (ignored): $e');
      }
    }

    // 2. Camera permission
    debugPrint('[CreateSheet] requesting camera permission');
    final camStatus = await Permission.camera.request();
    debugPrint('[CreateSheet] camera=$camStatus');
    if (!mounted) return;
    if (!camStatus.isGranted) {
      setState(() => _processingPost = false);
      _showPermissionDialog('Camera permission is required to create posts.');
      return;
    }

    // 3. Microphone permission (non-blocking — just request)
    await Permission.microphone.request();
    if (!mounted) return;

    // 4. Photos permission (isLimited is acceptable on iOS)
    debugPrint('[CreateSheet] requesting photos permission');
    final photosStatus = await Permission.photos.request();
    debugPrint('[CreateSheet] photos=$photosStatus');
    if (!mounted) return;

    // 5. All good — capture router BEFORE closing the sheet (widget will be
    //    disposed after pop, so we must not use context or mounted after that).
    final router = GoRouter.of(context);
    debugPrint('[CreateSheet] navigating to /camera');
    setState(() => _processingPost = false);
    Navigator.of(context, rootNavigator: true).pop();
    // router is a GoRouter singleton — safe to use after the sheet is disposed.
    final result = await router.push<Map<String, dynamic>>(
      '/camera',
      extra: {'initialMode': 'Post'},
    );
    if (result != null && result['capturedMedia'] != null) {
      router.push('/create-post', extra: {
        'capturedMedia': result['capturedMedia'],
        'fromCamera': result['fromCamera'] ?? true,
      });
    }
  }

  void _handleCreateCommunity() {
    final router = GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).pop();
    router.push('/create-group', extra: {'isCommunity': true});
  }

  void _handleCreateChannel() {
    final router = GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).pop();
    router.push('/create-channel');
  }

  void _handleListProperty() {
    final router = GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).pop();
    router.push('/create-property');
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text(message,
            style: const TextStyle(
                color: AppColors.textSecondary, fontFamily: 'Outfit', height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style: TextStyle(
                    color: AppColors.primaryButton,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(String message) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required',
            style: TextStyle(
                color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        content: Text(message,
            style: const TextStyle(
                color: AppColors.textSecondary, fontFamily: 'Outfit', height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(
                    color: AppColors.primaryButton,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final items = _buildItems();

    // Let the Column measure itself — no manual height math that can drift.
    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Constrain so it never overflows on tiny screens
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,  // ← sizes to content, never overflows
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Create',
              style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryButton, strokeWidth: 2),
              ),
            )
          else
            ...items.map((item) => _ActionTile(
                  item: item,
                  colors: c,
                  processing: _processingPost && item.label == 'Create Post',
                )),
          // Safe area bottom gap
          SizedBox(height: safeBottom + 16),
        ],
      ),
    );
  }

  List<_ActionItem> _buildItems() {
    final list = <_ActionItem>[];
    if (_flags.createPost) {
      list.add(_ActionItem(
        icon: const IconData(0xe348,
            fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
        label: 'Create Post',
        subtitle: 'Share photos & videos with everyone',
        onTap: _handleCreatePost,
      ));
    }
    if (_flags.createCommunity) {
      list.add(_ActionItem(
        icon: const IconData(0xe1ac,
            fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
        label: 'Create Community',
        subtitle: 'Build a group around your interests',
        onTap: _handleCreateCommunity,
      ));
    }
    if (_flags.createChannel && _isVerified) {
      list.add(_ActionItem(
        icon: const IconData(0xe134,
            fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
        label: 'Create Channel',
        subtitle: 'Broadcast content to your followers',
        onTap: _handleCreateChannel,
      ));
    }
    if (_isProfessional) {
      list.add(_ActionItem(
        icon: const IconData(0xe1e0,
            fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
        label: 'List Property',
        subtitle: 'Add a WiStay property listing',
        onTap: _handleListProperty,
      ));
    }
    return list;
  }
}

// ── Tile helpers ──────────────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  final ThemeColors colors;
  final bool processing;
  const _ActionTile({
    required this.item,
    required this.colors,
    this.processing = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: processing ? null : item.onTap,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryButton.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: AppColors.primaryButton, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: TextStyle(
                              color: colors.text,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(item.subtitle,
                          style: TextStyle(
                              color: colors.textTertiary,
                              fontFamily: 'Outfit',
                              fontSize: 12)),
                    ],
                  ),
                ),
                if (processing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.primaryButton, strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      color: colors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      );
}
