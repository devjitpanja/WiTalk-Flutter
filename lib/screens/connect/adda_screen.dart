import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/adda_provider.dart';
import '../../providers/audio_room_provider.dart';
import '../../widgets/common/witalk_header.dart';
import '../../widgets/connect/community_adda_card.dart';
import '../../widgets/connect/personal_adda_card.dart';
import '../../widgets/connect/upcoming_adda_card.dart';
import '../../widgets/connect/not_member_bottom_sheet.dart';

class AddaScreen extends ConsumerStatefulWidget {
  const AddaScreen({super.key});

  @override
  ConsumerState<AddaScreen> createState() => _AddaScreenState();
}

class _AddaScreenState extends ConsumerState<AddaScreen> with TickerProviderStateMixin {
  late final AnimationController _ring1Ctrl;
  late final AnimationController _ring2Ctrl;
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;

  @override
  void initState() {
    super.initState();

    _ring1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ring1Scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );
    _ring1Opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );

    _ring2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ring2Scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );
    _ring2Opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _ring2Ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    super.dispose();
  }

  void _handleJoinRoom(Map<String, dynamic> room) async {
    final isHostCurrently = ref.read(audioRoomProvider).isHost;
    final isActiveCurrently = ref.read(audioRoomProvider).isConnected;

    if (isActiveCurrently && isHostCurrently) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're hosting an adda. Close it first before joining another one."),
          backgroundColor: Color(0xFF074494),
          duration: Duration(milliseconds: 3500),
        ),
      );
      return;
    }

    final groupId = room['group_id']?.toString();
    final isMember = room['is_group_member'] == true || room['is_group_member'] == 1;
    final isMonetized = room['group_is_monetized'] == true || room['group_is_monetized'] == 1;
    final inviteCode = room['group_invite_code']?.toString();

    if (groupId != null && groupId.isNotEmpty) {
      if (!isMember) {
        if (isMonetized && inviteCode != null && inviteCode.isNotEmpty) {
          context.push('/community-info/$inviteCode');
          return;
        }
        NotMemberBottomSheet.show(
          context,
          groupName: room['group_name']?.toString() ?? 'Community',
          groupPicture: room['group_picture']?.toString(),
          passRequired: room['group_pass_required'] == true || room['group_pass_required'] == 1,
          inviteCode: inviteCode,
        );
        return;
      }

      final myJoinMethod = room['my_group_join_method']?.toString();
      final trialEndsAtStr = room['my_group_trial_ends_at']?.toString();
      bool trialExpired = false;
      if (myJoinMethod == 'trial' && trialEndsAtStr != null && trialEndsAtStr.isNotEmpty) {
        final trialEndsAt = DateTime.tryParse(trialEndsAtStr);
        if (trialEndsAt != null && trialEndsAt.isBefore(DateTime.now())) {
          trialExpired = true;
        }
      }

      if (isMonetized && (myJoinMethod == 'free' || trialExpired) && inviteCode != null && inviteCode.isNotEmpty) {
        context.push('/community-info/$inviteCode');
        return;
      }
    }

    final roomId = room['room_id']?.toString() ?? room['id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      context.push('/live-audio/$roomId', extra: {
        'room_name': room['room_name']?.toString() ?? 'WiTalk Adda',
        'is_host': room['host_uid']?.toString() == ref.read(authProvider).uid,
        'host_uid': room['host_uid']?.toString(),
      });
    }
  }

  void _handleDeleteScheduledAdda(Map<String, dynamic> room) {
    final roomName = room['room_name']?.toString() ?? 'Adda';
    final roomId = room['room_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        final c = context.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'Cancel Adda?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$roomName" will be permanently cancelled and followers will be notified.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Back', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (roomId.isNotEmpty) {
                  await ref.read(addaNotifierProvider.notifier).deleteScheduledRoom(roomId);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
              child: const Text('Cancel Adda', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleStartScheduledAdda(Map<String, dynamic> room) {
    final roomName = room['room_name']?.toString() ?? 'Adda';
    final roomId = room['room_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        final c = context.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'Start Adda Now?',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$roomName" will go live immediately and your followers will be notified.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (roomId.isNotEmpty) {
                  final success = await ref.read(addaNotifierProvider.notifier).startScheduledRoom(roomId);
                  if (success && mounted) {
                    context.push('/live-audio/$roomId');
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: c.primary),
              child: const Text('Start', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMicButton(bool canCreateAdda) {
    final c = context.colors;

    return GestureDetector(
      onTap: () {
        if (!canCreateAdda) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creating addas is currently disabled')),
          );
          return;
        }
        context.push('/create-audio-room');
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (canCreateAdda) ...[
              AnimatedBuilder(
                animation: _ring1Ctrl,
                builder: (context, child) => Opacity(
                  opacity: _ring1Opacity.value,
                  child: Transform.scale(
                    scale: _ring1Scale.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.primary, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ring2Ctrl,
                builder: (context, child) => Opacity(
                  opacity: _ring2Opacity.value,
                  child: Transform.scale(
                    scale: _ring2Scale.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.primary, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Opacity(
              opacity: canCreateAdda ? 1.0 : 0.45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: c.primary.withOpacity(0.12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: c.primary,
                  ),
                  child: Icon(
                    canCreateAdda ? Icons.mic : Icons.mic_off,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerBanner(String bannerText) {
    if (bannerText.isEmpty) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFB45309),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.36,
                fontWeight: FontWeight.w500,
                fontFamily: 'Outfit',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs(AddaState state, ThemeColors c, bool isDark) {
    final liveCount = state.rooms.length;
    final upcomingCount = state.upcomingRooms.length;
    final isLiveActive = state.activeTab == 'live';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live Tab
              GestureDetector(
                onTap: () => ref.read(addaNotifierProvider.notifier).switchTab('live'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLiveActive
                        ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    border: isLiveActive
                        ? Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          )
                        : null,
                    boxShadow: isLiveActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: isLiveActive ? FontWeight.w600 : FontWeight.w500,
                          color: isLiveActive ? c.text : c.textSecondary,
                        ),
                      ),
                      if (liveCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$liveCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Upcoming Tab
              GestureDetector(
                onTap: () => ref.read(addaNotifierProvider.notifier).switchTab('upcoming'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: !isLiveActive
                        ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    border: !isLiveActive
                        ? Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          )
                        : null,
                    boxShadow: !isLiveActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: !isLiveActive ? c.text : c.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Upcoming',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: !isLiveActive ? FontWeight.w600 : FontWeight.w500,
                          color: !isLiveActive ? c.text : c.textSecondary,
                        ),
                      ),
                      if (upcomingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$upcomingCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addaState = ref.watch(addaNotifierProvider);
    final settings = addaState.addaSettings;
    final canCreateAdda = settings['adda_server_enabled'] != false && settings['adda_creation_enabled'] != false;
    final serverBannerText = settings['adda_server_banner']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            WiTalkHeader(
              title: 'WiTalk',
              showBorder: false,
              showNotifications: true,
              leadingAction: Padding(
                padding: const EdgeInsets.all(4),
                child: _buildMicButton(canCreateAdda),
              ),
            ),
            _buildServerBanner(serverBannerText),
            _buildSegmentedTabs(addaState, c, isDark),
            Expanded(
              child: addaState.activeTab == 'live'
                  ? _buildLiveTab(addaState, c, canCreateAdda, isDark)
                  : _buildUpcomingTab(addaState, c, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTab(AddaState state, ThemeColors c, bool canCreateAdda, bool isDark) {
    if (state.isLoadingLive && state.groupedItems.isEmpty) {
      return _buildSkeleton(c);
    }

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: () => ref.read(addaNotifierProvider.notifier).refreshLive(),
      child: state.groupedItems.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                alignment: Alignment.center,
                child: _buildEmptyLive(c, canCreateAdda, isDark),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: state.groupedItems.length,
              itemBuilder: (ctx, i) {
                final item = state.groupedItems[i];
                final type = item['type']?.toString();

                if (type == 'community') {
                  final commId = item['communityId']?.toString() ?? '';
                  final isExpanded = state.expandedCommunities[commId] ?? true;
                  return CommunityAddaCard(
                    item: item,
                    isExpanded: isExpanded,
                    onToggleExpand: () {
                      ref.read(addaNotifierProvider.notifier).toggleCommunityExpand(commId);
                    },
                    onJoinRoom: _handleJoinRoom,
                  );
                }

                final room = (item['room'] as Map<String, dynamic>?) ?? {};
                return PersonalAddaCard(
                  room: room,
                  paletteIndex: i,
                  onJoinRoom: _handleJoinRoom,
                );
              },
            ),
    );
  }

  Widget _buildUpcomingTab(AddaState state, ThemeColors c, bool isDark) {
    if (state.isLoadingUpcoming && state.upcomingRooms.isEmpty) {
      return _buildSkeleton(c);
    }

    final currentUid = ref.read(authProvider).uid ?? '';

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: () => ref.read(addaNotifierProvider.notifier).refreshUpcoming(),
      child: state.upcomingRooms.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                alignment: Alignment.center,
                child: _buildEmptyUpcoming(c, isDark),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: state.upcomingRooms.length,
              itemBuilder: (ctx, i) {
                final room = state.upcomingRooms[i];
                final roomId = room['room_id']?.toString() ?? '';
                final isFollowing = state.followingMap[roomId] ?? false;
                final isOwnRoom = room['host_uid']?.toString() == currentUid;

                return UpcomingAddaCard(
                  room: room,
                  isFollowing: isFollowing,
                  isOwnRoom: isOwnRoom,
                  onToggleBell: () {
                    if (roomId.isNotEmpty) {
                      ref.read(addaNotifierProvider.notifier).toggleFollowSchedule(roomId);
                    }
                  },
                  onDelete: () => _handleDeleteScheduledAdda(room),
                  onStartNow: () => _handleStartScheduledAdda(room),
                );
              },
            ),
    );
  }

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        itemCount: 4,
        itemBuilder: (ctx, idx) => Shimmer.fromColors(
          baseColor: c.surface,
          highlightColor: c.border,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 140,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _buildEmptyLive(ThemeColors c, bool canCreateAdda, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF001A3D), Color(0xFF002D66)]
                    : const [Color(0xFFE8F4FF), Color(0xFFCCE5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.groups, size: 44, color: c.primary),
          ),
          const SizedBox(height: 22),
          Text(
            'No Live Addas Right Now',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              color: c.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'The stage is yours — spark a conversation and watch the crowd gather!',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Outfit',
              color: c.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Opacity(
            opacity: canCreateAdda ? 1.0 : 0.45,
            child: GestureDetector(
              onTap: () {
                if (!canCreateAdda) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Creating addas is currently disabled')),
                  );
                  return;
                }
                context.push('/create-audio-room');
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF0A84FF), Color(0xFF5AC8FA)]
                        : const [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(canCreateAdda ? Icons.mic : Icons.mic_off, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Start Your Adda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: 0.6,
            child: Text(
              'Free to create · Anyone can join',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Outfit',
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUpcoming(ThemeColors c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF001229), Color(0xFF001F47)]
                    : const [Color(0xFFE8F4FF), Color(0xFFD0E8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.event, size: 44, color: c.primary),
          ),
          const SizedBox(height: 22),
          Text(
            'Nothing Scheduled Yet',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              color: c.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Plan your adda ahead — let your followers mark their calendar!',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Outfit',
              color: c.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic, size: 15, color: c.textSecondary),
              const SizedBox(width: 4),
              Text(
                ' Tap mic button → Schedule Adda',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
