import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dashed_circle_painter.dart';
import 'participant_avatar.dart';

/// Premium redesigned GridSeatingLayout.
/// 4-column flex-wrap grid with improved visual hierarchy.
class GridSeatingLayout extends StatelessWidget {
  final List<Map<String, dynamic>> seats;
  final int maxSeats;
  final String? hostUid;
  final String? myUid;
  final String? activeSpeakerUid;
  final bool stageRequestEnabled;
  final bool isHost;
  final bool seatsInitialized;
  final List<Map<String, dynamic>> audience;

  final void Function(Map<String, dynamic> speaker)? onSpeakerTap;
  final void Function(int seatIndex)? onEmptySeatTap;
  final void Function(int seatIndex)? onLockedSeatTap;
  final void Function(int seatIndex)? onEmptySeatLongPress;
  final VoidCallback? onShowAudienceList;
  final void Function(Map<String, dynamic> member)? onAudienceMemberTap;

  const GridSeatingLayout({
    super.key,
    required this.seats,
    this.maxSeats = 8,
    this.hostUid,
    this.myUid,
    this.activeSpeakerUid,
    this.stageRequestEnabled = false,
    this.isHost = false,
    this.seatsInitialized = true,
    this.audience = const [],
    this.onSpeakerTap,
    this.onEmptySeatTap,
    this.onLockedSeatTap,
    this.onEmptySeatLongPress,
    this.onShowAudienceList,
    this.onAudienceMemberTap,
  });

  static const double _edgePadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final seatWidth = (screenWidth - _edgePadding * 2) / 4;
    final avatarSize = (seatWidth * 0.60).clamp(40.0, 62.0);
    final seatHeight = avatarSize * 1.5 + 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BAITHAK header ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x140751DF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x260751DF)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 11, color: Color(0xFF6E8FE0)),
                    SizedBox(width: 5),
                    Text(
                      'BAITHAK',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6E8FE0),
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x330751DF), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Stage Grid ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _edgePadding, vertical: 4),
          child: Wrap(
            spacing: 0,
            runSpacing: 6,
            children: List.generate(maxSeats, (index) {
              final seat = index < seats.length ? seats[index] : null;
              return _buildSeat(context, seat, index, seatWidth, avatarSize, seatHeight);
            }),
          ),
        ),

        // ── Audience row ────────────────────────────────────
        if (audience.isNotEmpty) _buildAudienceRow(context),
      ],
    );
  }

  Widget _buildSeat(BuildContext context, Map<String, dynamic>? seat, int index,
      double seatWidth, double avatarSize, double seatHeight) {
    final uidStr = seat?['uid']?.toString().trim();
    final bool isEmpty = seat == null ||
        seat['isEmpty'] == true ||
        uidStr == null ||
        uidStr.isEmpty ||
        uidStr == 'null';

    if (!isEmpty) {
      final uid = uidStr;
      final isSpeaking = activeSpeakerUid != null && uid == activeSpeakerUid;
      final isMuted = seat['isMuted'] == true;
      final isHostSeat = uid == hostUid || seat['isHost'] == true;

      return SizedBox(
        width: seatWidth,
        height: seatHeight,
        child: GestureDetector(
          onTap: () => onSpeakerTap?.call(seat),
          child: Center(
            child: ParticipantAvatar(
              uid: uid,
              name: seat['name']?.toString(),
              avatarUrl: seat['profile_pic']?.toString(),
              avatarFrameUrl: (seat['avatarFrameUrl'] ?? seat['avatar_frame_url'])?.toString(),
              isHost: isHostSeat,
              isAdmin: seat['isAdmin'] == true,
              communityRole: seat['communityRole']?.toString(),
              isVerified: seat['isVerified'] == true,
              verificationBadge: seat['verificationBadge'] as Map<String, dynamic>?,
              isMuted: isMuted,
              isSpeaking: isSpeaking,
              isSelf: uid == myUid,
              size: avatarSize,
            ),
          ),
        ),
      );
    }

    final bool isLocked = seat?['isLocked'] == true;
    if (isLocked) {
      return _buildLockedSeat(index, seatWidth, avatarSize, seatHeight);
    }
    return _buildEmptySeat(index, seatWidth, avatarSize, seatHeight);
  }

  Widget _buildEmptySeat(int index, double seatWidth, double avatarSize, double seatHeight) {
    final String seatText = seatsInitialized
        ? (isHost ? 'Hold to lock' : 'Join')
        : 'Syncing...';

    return SizedBox(
      width: seatWidth,
      height: seatHeight,
      child: GestureDetector(
        onTap: seatsInitialized ? () => onEmptySeatTap?.call(index) : null,
        onLongPress: seatsInitialized ? () => onEmptySeatLongPress?.call(index) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: CustomPaint(
                painter: const DashedCirclePainter(
                  color: Color(0x33FFFFFF),
                  strokeWidth: 1.5,
                  dashLength: 5.0,
                  dashGap: 4.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x0AFFFFFF),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: !seatsInitialized
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0x4DFFFFFF),
                          ),
                        )
                      : Icon(
                          Icons.add_rounded,
                          size: avatarSize * 0.40,
                          color: const Color(0x4DFFFFFF),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              seatText,
              style: const TextStyle(
                color: Color(0x73FFFFFF),
                fontSize: 9,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedSeat(int index, double seatWidth, double avatarSize, double seatHeight) {
    final String label = isHost ? 'Hold to unlock' : 'Seat ${index + 1}';

    return SizedBox(
      width: seatWidth,
      height: seatHeight,
      child: GestureDetector(
        onTap: () => onLockedSeatTap?.call(index),
        onLongPress: () => onEmptySeatLongPress?.call(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: CustomPaint(
                painter: const DashedCirclePainter(
                  color: Color(0xAAEF4444),
                  strokeWidth: 1.5,
                  dashLength: 5.0,
                  dashGap: 4.0,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x18EF4444),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_rounded,
                    size: avatarSize * 0.38,
                    color: const Color(0xAAEF4444),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0x73FFFFFF),
                fontSize: 9,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...audience.take(10).map((m) => _buildAudienceAvatar(m)),
                  if (audience.length > 10 && onShowAudienceList != null)
                    GestureDetector(
                      onTap: onShowAudienceList,
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x1A5B9AFF),
                          border: Border.all(
                            color: const Color(0x665B9AFF),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${audience.length - 10}',
                          style: const TextStyle(
                            color: Color(0xFF5B9AFF),
                            fontSize: 9,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onShowAudienceList,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x145B9AFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x665B9AFF), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_rounded, size: 13, color: Color(0xFF5B9AFF)),
                  const SizedBox(width: 5),
                  Text(
                    '${audience.length}',
                    style: const TextStyle(
                      color: Color(0xFF5B9AFF),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
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

  static String? _normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://files.witalk.in$trimmed';
    }
    return trimmed;
  }

  Widget _buildAudienceAvatar(Map<String, dynamic> member) {
    final avatar = _normalizeUrl(member['profile_pic']?.toString() ?? member['avatar']?.toString());
    final name = member['name']?.toString() ?? member['userName']?.toString() ?? 'U';

    return GestureDetector(
      onTap: () => onAudienceMemberTap?.call(member),
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D4A7A), Color(0xFF1A3050)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatar != null && avatar.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatar,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildLetterFallback(name),
                placeholder: (_, __) => _buildLetterFallback(name),
              )
            : _buildLetterFallback(name),
      ),
    );
  }

  Widget _buildLetterFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
