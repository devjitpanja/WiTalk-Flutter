import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../api/dio_client.dart';
import '../../providers/create_action_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/theme_colors.dart';
import '../../theme/app_colors.dart';

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showCreateActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CreateActionSheet(),
  );
}

// ── Bottom sheet widget ───────────────────────────────────────────────────────

class _CreateActionSheet extends ConsumerStatefulWidget {
  const _CreateActionSheet();
  @override
  ConsumerState<_CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends ConsumerState<_CreateActionSheet> {
  bool _processingPost = false;

  // ── Create Post ─────────────────────────────────────────────────────────────

  Future<void> _handleCreatePost() async {
    if (!mounted || _processingPost) return;
    setState(() => _processingPost = true);

    final uid = ref.read(userProvider)?.id;

    // 1. Post rate-limit check
    if (uid != null) {
      try {
        final res = await dioClient.get('/v1/config/post-limit/$uid');
        final data = res.data?['data'];
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
    final camStatus = await Permission.camera.request();
    if (!mounted) return;
    if (!camStatus.isGranted) {
      setState(() => _processingPost = false);
      _showPermissionDialog('Camera permission is required to create posts.');
      return;
    }

    // 3. Microphone (non-blocking)
    await Permission.microphone.request();
    if (!mounted) return;

    // 4. Photos (limited is acceptable on iOS)
    await Permission.photos.request();
    if (!mounted) return;

    // 5. Navigate
    final router = GoRouter.of(context);
    setState(() => _processingPost = false);
    Navigator.of(context, rootNavigator: true).pop();
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

    // Both providers are preloaded at app startup — reading them here is instant.
    final flags = ref.watch(createActionProvider);
    final user = ref.watch(userProvider);
    final isVerified = user?.isVerified ?? false;

    final items = _buildItems(flags: flags, isVerified: isVerified);

    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          // Header — title + subtitle, same as RN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create',
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What would you like to create?',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Outfit',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action list
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (idx > 0)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: c.border,
                  ),
                _ActionTile(
                  item: item,
                  colors: c,
                  processing: _processingPost && item.label == 'Create Post',
                ),
              ],
            );
          }),
          SizedBox(height: safeBottom + 16),
        ],
      ),
    );
  }

  List<_ActionItem> _buildItems({
    required CreateActionFlags flags,
    required bool isVerified,
  }) {
    final list = <_ActionItem>[];
    if (flags.createPost) {
      list.add(_ActionItem(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Create Post',
        subtitle: 'Share photos, videos, or thoughts',
        iconColor: const Color(0xFF0A84FF), // theme.primary blue
        onTap: _handleCreatePost,
      ));
    }
    if (flags.createCommunity) {
      list.add(_ActionItem(
        icon: Icons.group_add_outlined,
        label: 'Create Community',
        subtitle: 'Start a new community group',
        iconColor: const Color(0xFF34C759), // green — same as RN
        onTap: _handleCreateCommunity,
      ));
    }
    if (flags.createChannel && isVerified) {
      list.add(_ActionItem(
        icon: Icons.campaign_outlined,
        label: 'Create Channel',
        subtitle: 'Broadcast updates to your audience',
        iconColor: const Color(0xFFFF9500), // orange — same as RN
        onTap: _handleCreateChannel,
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
  final Color iconColor;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: processing ? null : item.onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colors.surface.withValues(alpha: 0.6),
        highlightColor: colors.surface.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // RN: iconColor + '20' = 12.5% opacity background
                  color: item.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontFamily: 'Outfit',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (processing)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: item.iconColor, strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: colors.textTertiary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
