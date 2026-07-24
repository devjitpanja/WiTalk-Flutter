import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../services/audio_room_service.dart';

class UserProfileBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? participant;
  final bool isHost;
  final bool isAdmin;
  final String? currentUserId;
  final String? hostUid;
  final VoidCallback? onFollowHost;
  final Function(Map<String, dynamic>)? onMute;
  final Function(Map<String, dynamic>)? onUnmute;
  final Function(Map<String, dynamic>)? onKick;
  final Function(Map<String, dynamic>)? onOffStage;
  final Function(Map<String, dynamic>)? onInviteToSeat;
  final Function(Map<String, dynamic>)? onTurnMicOn;
  final Function(Map<String, dynamic>)? onPromoteToAdmin;
  final Function(Map<String, dynamic>)? onDemoteAdmin;
  final double participantVolume;
  final Function(String, double)? onSetVolume;
  final Function(Map<String, dynamic>, bool)? onReportUser;
  final bool actionsFrozen;
  final bool isCommunityAdda;
  final String? myCommunityRole;
  final Map<String, dynamic>? communityRolesMap;
  final Function(Map<String, dynamic>, String?)? onCommunityKick;
  final Function(Map<String, dynamic>, String?)? onCommunityBan;
  final Function(Map<String, dynamic>, int)? onMoveToSeat;
  final List<dynamic>? seatsState;
  final int maxSeats;
  final bool isParticipantInSeat;

  const UserProfileBottomSheet({
    super.key,
    required this.participant,
    this.isHost = false,
    this.isAdmin = false,
    this.currentUserId,
    this.hostUid,
    this.onFollowHost,
    this.onMute,
    this.onUnmute,
    this.onKick,
    this.onOffStage,
    this.onInviteToSeat,
    this.onTurnMicOn,
    this.onPromoteToAdmin,
    this.onDemoteAdmin,
    this.participantVolume = 1.0,
    this.onSetVolume,
    this.onReportUser,
    this.actionsFrozen = false,
    this.isCommunityAdda = false,
    this.myCommunityRole,
    this.communityRolesMap,
    this.onCommunityKick,
    this.onCommunityBan,
    this.onMoveToSeat,
    this.seatsState,
    this.maxSeats = 8,
    this.isParticipantInSeat = false,
  });

  @override
  State<UserProfileBottomSheet> createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends State<UserProfileBottomSheet> {
  bool _isFollowing = false;
  bool _followLoading = false;
  bool _initialLoading = false;
  Map<String, dynamic>? _userProfileData;
  late double _localVolume;

  bool _showActionReasonModal = false;
  String _pendingAction = ''; // 'kick' | 'ban'
  String? _actionReasonChip;
  String _actionReasonCustom = '';
  
  bool _showSeatPicker = false;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.participantVolume;
    _fetchUserProfile();
  }
  
  static Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return const Color(0xFF0751DF);
  }

  int? _calcAge(String? birthday) {
    if (birthday == null) return null;
    try {
      final birth = DateTime.parse(birthday);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      return age > 0 ? age : null;
    } catch (_) { return null; }
  }

  String _getJoinedText(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0) return 'Joined today';
      if (diff == 1) return 'Joined yesterday';
      if (diff < 7) return 'Joined $diff days ago';
      if (diff < 30) return 'Joined ${(diff / 7).floor()}w ago';
      if (diff < 365) return 'Joined ${(diff / 30).floor()}mo ago';
      return 'Joined ${(diff / 365).floor()}y ago';
    } catch (_) { return 'Recently joined'; }
  }

  void _fetchUserProfile() async {
    final uid = widget.participant?['userID']?.toString();
    if (uid == null || uid.isEmpty) return;
    setState(() => _initialLoading = true);
    try {
      // Fetch profile and follow status in parallel
      final futures = await Future.wait([
        audioRoomService.getUserProfile(uid),
        if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty && widget.currentUserId != uid)
          audioRoomService.getFollowStatus(widget.currentUserId!, uid)
        else
          Future.value(false),
      ]);
      if (mounted) {
        final profileData = futures[0] as Map<String, dynamic>?;
        final isFollowing = futures[1] as bool;
        setState(() {
          if (profileData != null) _userProfileData = profileData;
          _isFollowing = isFollowing;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _initialLoading = false);
  }

  void _handleFollowToggle() async {
    final targetUid = widget.participant?['userID']?.toString();
    if (targetUid == null || targetUid.isEmpty || targetUid == widget.currentUserId) return;
    if (widget.currentUserId == null || widget.currentUserId!.isEmpty) return;

    // Optimistic update
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      _followLoading = true;
    });

    try {
      final result = await audioRoomService.toggleFollowUser(widget.currentUserId!, targetUid);
      if (mounted) {
        // Server may return explicit state; if not, keep the optimistic value
        bool nowFollowing;
        if (result.containsKey('data') && result['data'] is Map) {
          final d = result['data'] as Map;
          nowFollowing = d['isFollowing'] == true || d['is_following'] == true || d['following'] == true;
        } else if (result.containsKey('isFollowing')) {
          nowFollowing = result['isFollowing'] == true;
        } else if (result.containsKey('is_following')) {
          nowFollowing = result['is_following'] == true;
        } else if (result.containsKey('following')) {
          nowFollowing = result['following'] == true;
        } else {
          nowFollowing = !wasFollowing;
        }
        setState(() {
          _isFollowing = nowFollowing;
          _followLoading = false;
        });
        if (_isFollowing && targetUid == widget.hostUid) {
          widget.onFollowHost?.call();
        }
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followLoading = false;
        });
      }
    }
  }

  void _handleVisitProfile() {
    final uid = widget.participant?['userID']?.toString();
    if (uid == null || uid.isEmpty) return;
    Navigator.pop(context);
    Future.microtask(() => context.push('/user/$uid'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participant == null) return const SizedBox.shrink();

    final participant = widget.participant!;
    final isOwnProfile = participant['userID'] == widget.currentUserId;
    
    final participantCommunityRole = widget.communityRolesMap?[participant['userID']];
    final isParticipantCommunityOwner = participantCommunityRole == 'super_admin';
    final isParticipantCommunityAdmin = participantCommunityRole == 'admin';

    final iAmCommunityOwner = widget.myCommunityRole == 'super_admin';
    final iAmCommunityAdmin = widget.myCommunityRole == 'admin' || widget.myCommunityRole == 'super_admin';
    final targetIsProtectedOwner = isParticipantCommunityOwner && !iAmCommunityOwner;
    final canDoCommunityActions = widget.isCommunityAdda && iAmCommunityAdmin && !isOwnProfile && !isParticipantCommunityOwner && (!isParticipantCommunityAdmin || iAmCommunityOwner);

    final displayName = _userProfileData?['name'] ?? _userProfileData?['username'] ?? participant['userName'] ?? 'User';
    final avatarUrl = participant['avatar'] ?? _userProfileData?['profile_pic_medium'] ?? _userProfileData?['profile_pic'];
    final avatarFrameUrl = participant['avatar_frame_url']?.toString().isNotEmpty == true
        ? participant['avatar_frame_url']
        : (_userProfileData?['avatar_frame']?['image_url'] ?? _userProfileData?['avatar_frame_url']);

    // Profile extras from API
    final int? age = _calcAge(_userProfileData?['birthday']?.toString());
    final String? gender = _userProfileData?['gender']?.toString().toLowerCase();
    final String? joinedText = _userProfileData?['created_at'] != null
        ? _getJoinedText(_userProfileData!['created_at'].toString())
        : null;
    final bool isVerified = _userProfileData?['is_verified'] == true;
    final Map<String, dynamic>? verificationBadge =
        _userProfileData?['verification_badge'] is Map
            ? Map<String, dynamic>.from(_userProfileData!['verification_badge'] as Map)
            : (widget.participant?['verificationBadge'] is Map
                ? Map<String, dynamic>.from(widget.participant!['verificationBadge'] as Map)
                : null);
    final Color badgeColor = verificationBadge?['color'] != null
        ? _parseColor(verificationBadge!['color'].toString())
        : const Color(0xFF0751DF);

    List<String> interests = [];
    try {
      final raw = _userProfileData?['interests'];
      if (raw is List) {
        interests = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        // May be a JSON array string like '["Anime","Ceramics/Pottery"]'
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            interests = decoded.map((e) => e.toString()).toList();
          } else {
            interests = [raw];
          }
        } catch (_) {
          interests = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    } catch (_) {}

    List<String> purposes = [];
    try {
      final raw = _userProfileData?['purpose'];
      if (raw is List) {
        purposes = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            purposes = decoded.map((e) => e.toString()).toList();
          } else {
            purposes = [raw];
          }
        } catch (_) {
          purposes = [raw];
        }
      }
    } catch (_) {}

    // Avatar constants — frame is drawn 1.4× the avatar size (same ratio as RN)
    const double kAvatarSize = 72.0;
    const double kFrameMult = 1.44; // frame bleeds ~22% on each side
    final double kFrameBox = kAvatarSize * kFrameMult;
    final hasFrame = avatarFrameUrl != null && avatarFrameUrl.toString().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar with optional frame overlay (no margin inside Stack)
                            SizedBox(
                              width: hasFrame ? kFrameBox : kAvatarSize + 8,
                              height: hasFrame ? kFrameBox : kAvatarSize + 8,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Avatar circle — no border when frame present
                                  Container(
                                    width: kAvatarSize,
                                    height: kAvatarSize,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A90E2).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: !hasFrame
                                          ? Border.all(color: const Color(0xFF4A90E2), width: 2.5)
                                          : null,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    child: avatarUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: avatarUrl,
                                            width: kAvatarSize,
                                            height: kAvatarSize,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(Icons.person, size: 36, color: Colors.white.withOpacity(0.5)),
                                  ),
                                  // Frame — fills the outer SizedBox, sits above avatar
                                  if (hasFrame)
                                    Positioned.fill(
                                      child: CachedNetworkImage(
                                        imageUrl: avatarFrameUrl!,
                                        fit: BoxFit.contain,
                                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  // Online dot — anchored to the avatar circle edge
                                  Positioned(
                                    bottom: hasFrame ? (kFrameBox - kAvatarSize) * 0.38 : 0,
                                    right: hasFrame ? (kFrameBox - kAvatarSize) * 0.38 : 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF4CAF50),
                                        border: Border.all(color: const Color(0xFF141B26), width: 2.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name + verification + age/gender
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      if (isVerified)
                                        Icon(Icons.verified_rounded, size: 16, color: badgeColor),
                                      if (age != null && gender != null && (gender == 'male' || gender == 'female'))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: gender == 'male'
                                                ? const Color(0xFF003BA0).withOpacity(0.35)
                                                : const Color(0xFFC80078).withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                gender == 'male' ? Icons.male : Icons.female,
                                                size: 11,
                                                color: gender == 'male' ? const Color(0xFF5AABFF) : const Color(0xFFF062C0),
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '$age',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Outfit',
                                                  color: gender == 'male' ? const Color(0xFF5AABFF) : const Color(0xFFF062C0),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // Role badges
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (participant['isHost'] == true)
                                        _rolePill(Icons.star, 'Host', const Color(0xFFFFD700)),
                                      if (participant['isAdmin'] == true && participant['isHost'] != true)
                                        _rolePill(Icons.shield, 'Admin', const Color(0xFF4A90E2)),
                                      if (widget.isCommunityAdda && isParticipantCommunityOwner)
                                        _rolePill(Icons.star, 'Community Owner', const Color(0xFFF87171)),
                                      if (widget.isCommunityAdda && isParticipantCommunityAdmin)
                                        _rolePill(Icons.star, 'Community Admin', const Color(0xFFEAB308)),
                                    ],
                                  ),
                                  if (joinedText != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      joinedText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Outfit',
                                        color: Color(0x66FFFFFF),
                                      ),
                                    ),
                                  ],
                                  // Purposes
                                  if (purposes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: purposes.map((p) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A90E2).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.25)),
                                        ),
                                        child: Text(p, style: const TextStyle(fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFF4A90E2))),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Interests horizontal scroll
                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 30,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: interests.length > 5 ? 6 : interests.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              if (i == 5 && interests.length > 5) {
                                return Center(
                                  child: Text(
                                    '+${interests.length - 5}',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', color: Color(0x59FFFFFF)),
                                  ),
                                );
                              }
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(interests[i], style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0x99FFFFFF))),
                              );
                            },
                          ),
                        ),
                      ],

                      // Quick Actions — Follow | Profile | Volume | Report
                      if (!isOwnProfile) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildQuickActionBtn(
                              icon: _isFollowing ? Icons.check_circle : Icons.person_add,
                              label: _isFollowing ? 'Following' : 'Follow',
                              isActive: _isFollowing,
                              onTap: _handleFollowToggle,
                              isLoading: _followLoading || _initialLoading,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionBtn(
                              icon: Icons.account_circle,
                              label: 'Profile',
                              onTap: _handleVisitProfile,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionBtn(
                              icon: _localVolume == 0 ? Icons.volume_off : _localVolume < 0.5 ? Icons.volume_down : Icons.volume_up,
                              label: '${(_localVolume * 100).round()}%',
                              onTap: null,
                            ),
                            // Report — only shown for non-host/admin viewers
                            if (!widget.isHost && !widget.isAdmin) ...[
                              const SizedBox(width: 8),
                              _buildQuickActionBtn(
                                icon: Icons.flag,
                                label: 'Report',
                                iconColor: const Color(0xFFFF6B6B),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onReportUser?.call(participant, false);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Volume Control
                      if (!isOwnProfile)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Opacity(
                            opacity: widget.actionsFrozen ? 0.45 : 1.0,
                            child: Row(
                              children: [
                                Icon(
                                  _localVolume == 0 ? Icons.volume_off : _localVolume < 0.5 ? Icons.volume_down : Icons.volume_up,
                                  size: 18,
                                  color: widget.actionsFrozen ? Colors.white.withOpacity(0.2) : (_localVolume == 0 ? Colors.white.withOpacity(0.25) : const Color(0xFF4A90E2)),
                                ),
                                const SizedBox(width: 8),
                                _buildVolBtn(
                                  icon: Icons.remove,
                                  onTap: widget.actionsFrozen ? null : () {
                                    final next = math.max(0.0, ((_localVolume - 0.1) * 10).roundToDouble() / 10);
                                    setState(() => _localVolume = next);
                                    widget.onSetVolume?.call(participant['userID']?.toString() ?? '', next);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(10, (i) {
                                      final isFilled = i < (_localVolume * 10).round();
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: widget.actionsFrozen ? null : () {
                                          final next = (i + 1) / 10.0;
                                          setState(() => _localVolume = next);
                                          widget.onSetVolume?.call(participant['userID']?.toString() ?? '', next);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                                          child: Container(
                                            width: 8,
                                            height: 8.0 + (i * 2.0),
                                            decoration: BoxDecoration(
                                              color: isFilled
                                                  ? (widget.actionsFrozen ? const Color(0xFF4A90E2).withOpacity(0.25) : const Color(0xFF4A90E2))
                                                  : Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildVolBtn(
                                  icon: Icons.add,
                                  onTap: widget.actionsFrozen ? null : () {
                                    final next = math.min(1.0, ((_localVolume + 0.1) * 10).roundToDouble() / 10);
                                    setState(() => _localVolume = next);
                                    widget.onSetVolume?.call(participant['userID']?.toString() ?? '', next);
                                  },
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${(_localVolume * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: widget.actionsFrozen ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                if (widget.actionsFrozen)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Icon(Icons.lock, size: 12, color: const Color(0xFF8B5CF6).withOpacity(0.6)),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // Manage Section
                      if (((widget.isHost || widget.isAdmin) || canDoCommunityActions) && !isOwnProfile && !targetIsProtectedOwner)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'MANAGE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.3),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  if (widget.actionsFrozen) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.lock, size: 10, color: const Color(0xFFA78BFA)),
                                          const SizedBox(width: 3),
                                          const Text(
                                            'FROZEN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFA78BFA),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 9,
                                runSpacing: 9,
                                children: [
                                  if ((widget.isHost || widget.isAdmin) && participant['isHost'] != true && widget.isParticipantInSeat) ...[
                                    _buildManageCell(
                                      icon: participant['isMicOn'] == true ? Icons.mic_off : Icons.mic,
                                      label: participant['isMicOn'] == true ? 'Mute' : 'Unmute',
                                      color: const Color(0xFFFFA500),
                                      onTap: widget.actionsFrozen ? null : () {
                                        if (participant['isMicOn'] == true) {
                                          widget.onMute?.call(participant);
                                        } else {
                                          widget.onUnmute?.call(participant);
                                        }
                                        Navigator.pop(context);
                                      },
                                      isFrozen: widget.actionsFrozen,
                                    ),
                                    _buildManageCell(
                                      icon: Icons.transfer_within_a_station,
                                      label: 'Move Seat',
                                      color: const Color(0xFFA855F7),
                                      onTap: widget.actionsFrozen ? null : () => setState(() => _showSeatPicker = true),
                                      isFrozen: widget.actionsFrozen,
                                    ),
                                    _buildManageCell(
                                      icon: Icons.person_remove,
                                      label: 'Off Stage',
                                      color: const Color(0xFF4A90E2),
                                      onTap: widget.actionsFrozen ? null : () {
                                        widget.onOffStage?.call(participant);
                                        Navigator.pop(context);
                                      },
                                      isFrozen: widget.actionsFrozen,
                                    ),
                                  ] else if ((widget.isHost || widget.isAdmin) && participant['isHost'] != true && !widget.isParticipantInSeat) ...[
                                    _buildManageCell(
                                      icon: Icons.event_seat,
                                      label: 'Invite',
                                      color: const Color(0xFF4CAF50),
                                      onTap: () {
                                        widget.onInviteToSeat?.call(participant);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],

                                  if (widget.isCommunityAdda && iAmCommunityAdmin && participant['isHost'] == true && widget.isParticipantInSeat)
                                    _buildManageCell(
                                      icon: participant['isMicOn'] == true ? Icons.mic_off : Icons.mic,
                                      label: participant['isMicOn'] == true ? 'Mute' : 'Unmute',
                                      color: const Color(0xFFFFA500),
                                      onTap: widget.actionsFrozen ? null : () {
                                        if (participant['isMicOn'] == true) {
                                          widget.onMute?.call(participant);
                                        } else {
                                          widget.onUnmute?.call(participant);
                                        }
                                        Navigator.pop(context);
                                      },
                                      isFrozen: widget.actionsFrozen,
                                    ),

                                  if (widget.isHost && participant['isHost'] != true)
                                    _buildManageCell(
                                      icon: participant['isAdmin'] == true ? Icons.remove_moderator : Icons.add_moderator,
                                      label: participant['isAdmin'] == true ? 'Rm Admin' : 'Mk Admin',
                                      color: participant['isAdmin'] == true ? const Color(0xFFFFA500) : const Color(0xFF4A90E2),
                                      onTap: () {
                                        if (participant['isAdmin'] == true) {
                                          widget.onDemoteAdmin?.call(participant);
                                        } else {
                                          widget.onPromoteToAdmin?.call(participant);
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),

                                  if ((widget.isHost || widget.isAdmin) && participant['isHost'] != true) ...[
                                    _buildManageCell(
                                      icon: Icons.logout,
                                      label: 'Kick',
                                      color: const Color(0xFFFF6B6B),
                                      onTap: widget.actionsFrozen ? null : () {
                                        widget.onKick?.call(participant);
                                        Navigator.pop(context);
                                      },
                                      isFrozen: widget.actionsFrozen,
                                    ),
                                    _buildManageCell(
                                      icon: Icons.block,
                                      label: 'Ban',
                                      color: const Color(0xFFCC0000),
                                      onTap: widget.actionsFrozen ? null : () {
                                        Navigator.pop(context);
                                        widget.onReportUser?.call(participant, true);
                                      },
                                      isFrozen: widget.actionsFrozen,
                                    ),
                                  ],

                                  if (canDoCommunityActions) ...[
                                    _buildManageCell(
                                      icon: Icons.group_remove,
                                      label: 'Kick Comm.',
                                      color: const Color(0xFFFB923C),
                                      onTap: () {
                                        setState(() {
                                          _pendingAction = 'kick';
                                          _actionReasonChip = null;
                                          _actionReasonCustom = '';
                                          _showActionReasonModal = true;
                                        });
                                      },
                                      borderColor: const Color(0xFFFB923C).withOpacity(0.2),
                                    ),
                                    _buildManageCell(
                                      icon: Icons.person_off,
                                      label: 'Ban Comm.',
                                      color: const Color(0xFFEF4444),
                                      onTap: () {
                                        setState(() {
                                          _pendingAction = 'ban';
                                          _actionReasonChip = null;
                                          _actionReasonCustom = '';
                                          _showActionReasonModal = true;
                                        });
                                      },
                                      borderColor: const Color(0xFFEF4444).withOpacity(0.2),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (_showSeatPicker)
            _buildSeatPickerOverlay(),
            
          if (_showActionReasonModal)
            _buildReasonModalOverlay(participant),
        ],
      ),
    );
  }

  Widget _rolePill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Outfit', color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isLoading = false,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF4A90E2).withOpacity(0.12) : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: isActive ? const Color(0xFF4A90E2).withOpacity(0.3) : Colors.white.withOpacity(0.08),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90E2)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: iconColor ?? (isActive ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.85))),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: iconColor ?? (isActive ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolBtn({required IconData icon, required VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: widget.actionsFrozen ? const Color(0xFF4A90E2).withOpacity(0.25) : const Color(0xFF4A90E2)),
        ),
      ),
    );
  }

  Widget _buildManageCell({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isFrozen = false,
    Color? borderColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (MediaQuery.of(context).size.width - 36 - 27) / 4; // 4 columns, padding 18x2, 3 gaps of 9
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.07)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Opacity(
                opacity: isFrozen ? 0.45 : 1.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: isFrozen ? color.withOpacity(0.3) : color),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isFrozen ? color.withOpacity(0.35) : (borderColor != null ? color : Colors.white.withOpacity(0.75)),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildSeatPickerOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF141B26),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).padding.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Move to Seat',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an available seat for ${widget.participant?['userName']}',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: List.generate(widget.maxSeats, (index) {
                  final isOccupied = widget.seatsState != null && widget.seatsState!.length > index && widget.seatsState![index] != null;
                  
                  return GestureDetector(
                    onTap: () {
                      if (!isOccupied) {
                        setState(() => _showSeatPicker = false);
                        Navigator.pop(context);
                        widget.onMoveToSeat?.call(widget.participant!, index);
                      }
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 36 - 30) / 4,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isOccupied ? Colors.white.withOpacity(0.03) : const Color(0xFF4CAF50).withOpacity(0.08),
                        border: Border.all(color: isOccupied ? Colors.white.withOpacity(0.07) : const Color(0xFF4CAF50).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_seat,
                            size: 22,
                            color: isOccupied ? Colors.white.withOpacity(0.2) : const Color(0xFF4CAF50),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            index == 0 ? 'Host' : '#${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOccupied ? Colors.white.withOpacity(0.25) : const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _showSeatPicker = false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonModalOverlay(Map<String, dynamic> participant) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2336),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pendingAction == 'ban' ? 'Ban from Community' : 'Kick from Community',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _pendingAction == 'ban' 
                  ? 'Ban ${participant['userName']}? They will be removed from the community and won\'t be able to rejoin.'
                  : 'Kick ${participant['userName']} from the community?',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55), height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                'REASON (OPTIONAL)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.4), letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Abusive behaviour', 'Spam', 'Harassment', 'Hate speech', 'Promotion/Ads', 'Other'].map((chip) {
                  final isSelected = _actionReasonChip == chip;
                  return GestureDetector(
                    onTap: () => setState(() => _actionReasonChip = isSelected ? null : chip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF60A5FA).withOpacity(0.12) : Colors.transparent,
                        border: Border.all(color: isSelected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_actionReasonChip == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => setState(() => _actionReasonCustom = val),
                  maxLength: 200,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Describe the reason...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                    counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _showActionReasonModal = false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.55))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        final reason = _actionReasonChip == 'Other' ? (_actionReasonCustom.trim().isEmpty ? 'Other' : _actionReasonCustom.trim()) : _actionReasonChip;
                        setState(() => _showActionReasonModal = false);
                        Navigator.pop(context);
                        if (_pendingAction == 'ban') {
                          widget.onCommunityBan?.call(participant, reason);
                        } else {
                          widget.onCommunityKick?.call(participant, reason);
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: _pendingAction == 'ban' ? const Color(0xFFEF4444) : const Color(0xFFFB923C),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_pendingAction == 'ban' ? 'Ban' : 'Kick', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showUserProfileBottomSheet({
  required BuildContext context,
  required Map<String, dynamic>? participant,
  bool isHost = false,
  bool isAdmin = false,
  String? currentUserId,
  String? hostUid,
  VoidCallback? onFollowHost,
  Function(Map<String, dynamic>)? onMute,
  Function(Map<String, dynamic>)? onUnmute,
  Function(Map<String, dynamic>)? onKick,
  Function(Map<String, dynamic>)? onOffStage,
  Function(Map<String, dynamic>)? onInviteToSeat,
  Function(Map<String, dynamic>)? onTurnMicOn,
  Function(Map<String, dynamic>)? onPromoteToAdmin,
  Function(Map<String, dynamic>)? onDemoteAdmin,
  double participantVolume = 1.0,
  Function(String, double)? onSetVolume,
  Function(Map<String, dynamic>, bool)? onReportUser,
  bool actionsFrozen = false,
  bool isCommunityAdda = false,
  String? myCommunityRole,
  Map<String, dynamic>? communityRolesMap,
  Function(Map<String, dynamic>, String?)? onCommunityKick,
  Function(Map<String, dynamic>, String?)? onCommunityBan,
  Function(Map<String, dynamic>, int)? onMoveToSeat,
  List<dynamic>? seatsState,
  int maxSeats = 8,
  bool isParticipantInSeat = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UserProfileBottomSheet(
      participant: participant,
      isHost: isHost,
      isAdmin: isAdmin,
      currentUserId: currentUserId,
      hostUid: hostUid,
      onFollowHost: onFollowHost,
      onMute: onMute,
      onUnmute: onUnmute,
      onKick: onKick,
      onOffStage: onOffStage,
      onInviteToSeat: onInviteToSeat,
      onTurnMicOn: onTurnMicOn,
      onPromoteToAdmin: onPromoteToAdmin,
      onDemoteAdmin: onDemoteAdmin,
      participantVolume: participantVolume,
      onSetVolume: onSetVolume,
      onReportUser: onReportUser,
      actionsFrozen: actionsFrozen,
      isCommunityAdda: isCommunityAdda,
      myCommunityRole: myCommunityRole,
      communityRolesMap: communityRolesMap,
      onCommunityKick: onCommunityKick,
      onCommunityBan: onCommunityBan,
      onMoveToSeat: onMoveToSeat,
      seatsState: seatsState,
      maxSeats: maxSeats,
      isParticipantInSeat: isParticipantInSeat,
    ),
  );
}
