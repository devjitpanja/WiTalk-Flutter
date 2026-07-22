import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/adda_provider.dart';
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

    _ring1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _ring1Scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );
    _ring1Opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );

    _ring2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _ring2Scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );
    _ring2Opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _ring2Ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    super.dispose();
  }

  void _handleJoinRoom(Map<String, dynamic> room) {
    final groupId = room['group_id']?.toString();
    final isMember = room['is_group_member'] == true || room['is_group_member'] == 1;

    // Non-member trying to join community adda
    if (groupId != null && groupId.isNotEmpty && !isMember) {
      NotMemberBottomSheet.show(
        context,
        groupName: room['group_name']?.toString() ?? 'Community',
        groupPicture: room['group_picture']?.toString(),
        passRequired: room['group_pass_required'] == true || room['group_pass_required'] == 1,
        inviteCode: room['group_invite_code']?.toString(),
      );
      return;
    }

    final roomId = room['room_id']?.toString() ?? room['id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      context.push('/live-audio/$roomId');
    }
  }

  Widget _buildMicButton(bool canCreateAdda) {
    final c = context.colors;
    final primaryColor = canCreateAdda ? c.primaryButton : c.textSecondary;

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
        width: 42,
        height: 42,
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor, width: 1.5),
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canCreateAdda ? c.primaryButton : c.surface,
              ),
              child: Icon(
                canCreateAdda ? Icons.mic : Icons.mic_off,
                size: 18,
                color: canCreateAdda ? Colors.white : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChips(AddaState state, ThemeColors c) {
    final liveCount = state.rooms.length;
    final upcomingCount = state.upcomingRooms.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _TabChip(
            label: 'Live Addas',
            count: liveCount,
            isSelected: state.activeTab == 'live',
            onTap: () => ref.read(addaNotifierProvider.notifier).switchTab('live'),
          ),
          const SizedBox(width: 10),
          _TabChip(
            label: 'Upcoming',
            count: upcomingCount,
            isSelected: state.activeTab == 'upcoming',
            onTap: () => ref.read(addaNotifierProvider.notifier).switchTab('upcoming'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final addaState = ref.watch(addaNotifierProvider);
    final settings = addaState.addaSettings;
    final canCreateAdda = settings['adda_server_enabled'] != false && settings['adda_creation_enabled'] != false;

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
                padding: const EdgeInsets.all(6),
                child: _buildMicButton(canCreateAdda),
              ),
            ),
            _buildTabChips(addaState, c),
            Expanded(
              child: addaState.activeTab == 'live'
                  ? _buildLiveTab(addaState, c)
                  : _buildUpcomingTab(addaState, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTab(AddaState state, ThemeColors c) {
    if (state.isLoadingLive && state.groupedItems.isEmpty) {
      return _buildSkeleton(c);
    }

    return RefreshIndicator(
      color: c.primaryButton,
      backgroundColor: c.surface,
      onRefresh: () => ref.read(addaNotifierProvider.notifier).refreshLive(),
      child: state.groupedItems.isEmpty
          ? _buildEmpty(c, 'No live rooms right now', 'Start a room to begin talking')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildUpcomingTab(AddaState state, ThemeColors c) {
    if (state.isLoadingUpcoming && state.upcomingRooms.isEmpty) {
      return _buildSkeleton(c);
    }

    return RefreshIndicator(
      color: c.primaryButton,
      backgroundColor: c.surface,
      onRefresh: () => ref.read(addaNotifierProvider.notifier).refreshUpcoming(),
      child: state.upcomingRooms.isEmpty
          ? _buildEmpty(c, 'No scheduled addas', 'Check back later for upcoming discussions')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.upcomingRooms.length,
              itemBuilder: (ctx, i) {
                final room = state.upcomingRooms[i];
                final roomId = room['room_id']?.toString() ?? '';
                final isFollowing = state.followingMap[roomId] ?? false;

                return UpcomingAddaCard(
                  room: room,
                  isFollowing: isFollowing,
                  onToggleBell: () {
                    if (roomId.isNotEmpty) {
                      ref.read(addaNotifierProvider.notifier).toggleFollowSchedule(roomId);
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 4,
        itemBuilder: (ctx, idx) => Shimmer.fromColors(
          baseColor: c.surface,
          highlightColor: c.border,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 120,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _buildEmpty(ThemeColors c, String title, String subtitle) => Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎙️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/create-audio-room'),
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('Start an Adda', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primaryButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bgColor = isSelected ? c.primaryButton : c.surface;
    final fgColor = isSelected ? Colors.white : c.text;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c.primaryButton : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Outfit',
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : c.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
