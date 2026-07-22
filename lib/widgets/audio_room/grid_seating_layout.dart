import 'package:flutter/material.dart';
import 'participant_avatar.dart';

/// Pixel-perfect port of RN GridSeatingLayout.
/// 4-column flex-wrap grid of seats (occupied/empty/locked/reserved).
/// Below the grid: audience horizontal scroll row.
class GridSeatingLayout extends StatelessWidget {
  final List<Map<String, dynamic>> seats; // [{isEmpty, uid, name, profile_pic, isHost, isMuted, isSelf, seatIndex}]
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
    this.onShowAudienceList,
    this.onAudienceMemberTap,
  });

  static const double _edgePadding = 5.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final seatWidth = (screenWidth - _edgePadding * 2) / 4;
    final avatarSize = (seatWidth * 0.65).clamp(40.0, 64.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BAITHAK section header ────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
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
            runSpacing: 10,
            children: List.generate(maxSeats, (index) {
              final seat = index < seats.length ? seats[index] : null;
              return _buildSeat(context, seat, index, seatWidth, avatarSize);
            }),
          ),
        ),

        // ── Audience row ──────────────────────────────────
        if (audience.isNotEmpty) _buildAudienceRow(context),
      ],
    );
  }

  Widget _buildSeat(BuildContext context, Map<String, dynamic>? seat, int index,
      double seatWidth, double avatarSize) {
    final bool isEmpty = seat == null || seat['isEmpty'] == true || seat['uid'] == null;

    if (!isEmpty) {
      final uid = seat!['uid']?.toString() ?? '';
      final isSpeaking = activeSpeakerUid != null && uid == activeSpeakerUid;
      final isMuted = seat['isMuted'] == true;
      final isHostSeat = uid == hostUid || seat['isHost'] == true;

      return SizedBox(
        width: seatWidth,
        child: GestureDetector(
          onTap: () => onSpeakerTap?.call(seat),
          child: ParticipantAvatar(
            uid: uid,
            name: seat['name']?.toString(),
            avatarUrl: seat['profile_pic']?.toString(),
            isHost: isHostSeat,
            isMuted: isMuted,
            isSpeaking: isSpeaking,
            isSelf: uid == myUid,
            size: avatarSize,
          ),
        ),
      );
    }

    // Determine locked state
    final bool isLocked = seat?['isLocked'] == true;

    if (isLocked) {
      return _buildLockedSeat(index, seatWidth, avatarSize);
    }

    return _buildEmptySeat(index, seatWidth, avatarSize);
  }

  Widget _buildEmptySeat(int index, double seatWidth, double avatarSize) {
    return SizedBox(
      width: seatWidth,
      child: GestureDetector(
        onTap: seatsInitialized ? () => onEmptySeatTap?.call(index) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x14FFFFFF),
                border: Border.all(
                  color: const Color(0x26FFFFFF),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: !seatsInitialized
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0x4DFFFFFF),
                      ),
                    )
                  : Icon(
                      Icons.event_seat,
                      size: avatarSize * 0.45,
                      color: const Color(0x4DFFFFFF),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              seatsInitialized ? 'Seat ${index + 1}' : 'Syncing...',
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedSeat(int index, double seatWidth, double avatarSize) {
    return SizedBox(
      width: seatWidth,
      child: GestureDetector(
        onTap: () => onLockedSeatTap?.call(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x26FF6B6B),
                border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.lock, size: avatarSize * 0.4, color: const Color(0xFFFF6B6B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Seat ${index + 1}',
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
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
                          style: const TextStyle(fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFF4A90E2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1A5B9AFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x405B9AFF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, size: 12, color: Color(0xFF5B9AFF)),
                const SizedBox(width: 3),
                Text(
                  '${audience.length}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Color(0xFF5B9AFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceAvatar(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? member['uid']?.toString() ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final avatarUrl = member['profile_pic']?.toString();

    return GestureDetector(
      onTap: () => onAudienceMemberTap?.call(member),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _audienceInitial(initial))
            : _audienceInitial(initial),
      ),
    );
  }

  Widget _audienceInitial(String initial) {
    return Container(
      color: const Color(0x1AFFFFFF),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
