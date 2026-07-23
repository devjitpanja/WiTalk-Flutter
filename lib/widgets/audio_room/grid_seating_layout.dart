import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dashed_circle_painter.dart';
import 'participant_avatar.dart';

/// Pixel-perfect port of RN GridSeatingLayout.
/// 4-column flex-wrap grid of seats (occupied/empty/locked/reserved).
/// Below the grid: audience horizontal scroll row.
class GridSeatingLayout extends StatelessWidget {
  final List<Map<String, dynamic>> seats; // [{isEmpty, uid, name, profile_pic, avatar_frame_url, isHost, isMuted, isSelf, seatIndex, isLocked}]
  final int maxSeats;
  final String? hostUid;
  final String? myUid;
  final String? activeSpeakerUid;
  final bool stageRequestEnabled;
  final bool isHost;
  final bool seatsInitialized;

  /// Audience members (not in any seat)
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

  static const double _edgePadding = 5.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final seatWidth = (screenWidth - _edgePadding * 2) / 4;
    final avatarSize = (seatWidth * 0.65).clamp(40.0, 64.0);
    // Fixed row height: largest possible avatar box (frame = 1.5×) + name label
    final seatHeight = avatarSize * 1.5 + 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BAITHAK section header ────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              const Icon(
                Icons.people,
                size: 12,
                color: Color(0x99828CF8),
              ),
              const SizedBox(width: 5),
              const Text(
                'BAITHAK',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: Color(0x99828CF8),
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: const Color(0x1F0751DF)),
              ),
            ],
          ),
        ),

        // ── Stage Grid ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _edgePadding, vertical: 8),
          child: Wrap(
            spacing: 0,
            runSpacing: 4,
            children: List.generate(maxSeats, (index) {
              final seat = index < seats.length ? seats[index] : null;
              return _buildSeat(context, seat, index, seatWidth, avatarSize, seatHeight);
            }),
          ),
        ),

        // ── Audience row ──────────────────────────────────
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
      final uid = uidStr!;
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
        ? (isHost && index != 0 ? 'Hold to lock' : 'Hold to lock')
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
                  color: Color(0x26FFFFFF),
                  strokeWidth: 2.0,
                  dashLength: 5.0,
                  dashGap: 3.5,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x14FFFFFF),
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
                          Icons.event_seat,
                          size: avatarSize * 0.48,
                          color: const Color(0x4DFFFFFF),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              seatText,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
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
    final String label = isHost && index != 0 ? 'Hold to unlock' : 'Seat ${index + 1}';

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
                  color: Color(0xFFFF6B6B),
                  strokeWidth: 2.0,
                  dashLength: 5.0,
                  dashGap: 3.5,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x26FF6B6B),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock,
                    size: avatarSize * 0.42,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
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
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...audience.take(10).map((m) => _buildAudienceAvatar(m)),
                  if (audience.length > 10 && onShowAudienceList != null)
                    GestureDetector(
                      onTap: onShowAudienceList,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x334A90E2),
                          border: Border.all(color: const Color(0xFF4A90E2), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${audience.length - 10}',
                          style: const TextStyle(
                            color: Color(0xFF4A90E2),
                            fontSize: 10,
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
          GestureDetector(
            onTap: onShowAudienceList,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x334A90E2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4A90E2), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 14, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 4),
                  Text(
                    '${audience.length}',
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
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
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
          color: const Color(0x1AFFFFFF),
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
          fontSize: 12,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
