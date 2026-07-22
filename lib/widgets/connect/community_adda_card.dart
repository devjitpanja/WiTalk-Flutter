import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

const Map<String, dynamic> _communityPalette = {
  'gradientLight': [Color(0xFFFFFFFF), Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
  'gradientDark': [Color(0xFF130828), Color(0xFF18093E), Color(0xFF1E1048)],
  'border': Color(0xFF8B5CF6),
  'accent': Color(0xFF7C3AED),
  'accentLight': Color(0xFFA78BFA),
  'joinGradient': [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
};

class CommunityAddaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Function(Map<String, dynamic> room) onJoinRoom;

  const CommunityAddaCard({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onJoinRoom,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final communityId = item['communityId']?.toString() ?? '';
    final communityName = item['communityName']?.toString() ?? 'Community';
    final communityPicture = item['communityPicture']?.toString();
    final memberCount = item['memberCount'];
    final isMember = item['isMember'] == true;
    final inviteCode = item['inviteCode']?.toString();
    final isMonetized = item['isMonetized'] == true;
    final myJoinMethod = item['myJoinMethod']?.toString();

    final addas = (item['addas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final liveCount = addas.length;

    final gradientColors = (isDark
        ? _communityPalette['gradientDark']
        : _communityPalette['gradientLight']) as List<Color>;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.33), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row — Tapping navigates to CommunityAddaListScreen / CommunityInfo
              GestureDetector(
                onTap: () {
                  if (isMonetized && inviteCode != null && (!isMember || myJoinMethod == 'free')) {
                    context.push('/community-info/$inviteCode');
                    return;
                  }
                  context.push(
                    '/community-adda-list/$communityId',
                    extra: {
                      'groupName': communityName,
                      'groupPicture': communityPicture,
                      'isMember': isMember,
                      'groupInviteCode': inviteCode,
                      'groupIsMonetized': isMonetized,
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.44), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: communityPicture != null && communityPicture.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: communityPicture,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF7C3AED).withOpacity(0.13),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.group, size: 22, color: Color(0xFF7C3AED)),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF7C3AED).withOpacity(0.13),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.group, size: 22, color: Color(0xFF7C3AED)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + Meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    communityName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Live chip with dot
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.28)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$liveCount Live',
                                        style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Community',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (memberCount != null) ...[
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people, size: 11, color: Color(0xFF7C3AED)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$memberCount Members',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Outfit',
                                        color: isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right, size: 22, color: Color(0xFF7C3AED)),
                    ],
                  ),
                ),
              ),

              // Adda List inside community card
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: const Color(0xFF8B5CF6).withOpacity(0.19),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Multiple Addas happening in this community',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(addas.length, (idx) {
                      final room = addas[idx];
                      return _buildAddaRow(context, room, idx, isDark);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddaRow(BuildContext context, Map<String, dynamic> room, int index, bool isDark) {
    final title = room['room_name']?.toString() ?? 'Community Adda';
    final hostDisplayName = room['host_name']?.toString() ?? room['host_username']?.toString() ?? 'Host';
    final hostPic = room['host_profile_pic']?.toString();
    final language = room['language']?.toString();
    final participantCount = (room['current_participants_count'] as int?) ?? 0;

    final rawParticipants = (room['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final seenIds = <String>{};
    final participants = <Map<String, dynamic>>[];
    for (final p in rawParticipants) {
      final pid = p['id']?.toString() ?? p['uid']?.toString() ?? '';
      if (pid.isEmpty || !seenIds.contains(pid)) {
        if (pid.isNotEmpty) seenIds.add(pid);
        participants.add(p);
      }
    }
    final extraCount = math.max(0, participantCount - 2);

    return GestureDetector(
      onTap: () => onJoinRoom(room),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: index > 0
              ? Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Host Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.38), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: hostPic != null && hostPic.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: hostPic,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF7C3AED).withOpacity(0.13),
                          alignment: Alignment.center,
                          child: const Icon(Icons.person, size: 14, color: Color(0xFF7C3AED)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF7C3AED).withOpacity(0.13),
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, size: 14, color: Color(0xFF7C3AED)),
                      ),
              ),
            ),
            const SizedBox(width: 10),

            // Title + Host Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hostDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: const Text(
                          '👑 Host',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      if (language != null && language.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          language,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Right: Participant stack + listener count + Join Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (participants.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final visibleCount = math.min(2, participants.length);
                      final totalBadges = visibleCount + (extraCount > 0 ? 1 : 0);
                      final stackWidth = 24.0 + (totalBadges - 1) * 14.0;
                      return SizedBox(
                        width: stackWidth,
                        height: 24,
                        child: Stack(
                          children: [
                            for (int i = 0; i < visibleCount; i++) ...[
                              Positioned(
                                left: i * 14.0,
                                top: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 1.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: () {
                                      final p = participants[i];
                                      final pic = p['profile_pic']?.toString() ?? p['avatar']?.toString() ?? p['picture']?.toString();
                                      if (pic != null && pic.isNotEmpty) {
                                        return CachedNetworkImage(
                                          imageUrl: pic,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: const Color(0xFF7C3AED).withOpacity(0.15),
                                            child: const Icon(Icons.person, size: 10, color: Color(0xFF7C3AED)),
                                          ),
                                        );
                                      }
                                      return Container(
                                        color: const Color(0xFF7C3AED).withOpacity(0.15),
                                        child: const Icon(Icons.person, size: 10, color: Color(0xFF7C3AED)),
                                      );
                                    }(),
                                  ),
                                ),
                              ),
                            ],
                            if (extraCount > 0)
                              Positioned(
                                left: visibleCount * 14.0,
                                top: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF7C3AED).withOpacity(0.25),
                                    border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+$extraCount',
                                    style: const TextStyle(
                                      color: Color(0xFF7C3AED),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.headset, size: 11, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 3),
                      Text(
                        '$participantCount',
                        style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.headset, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Join',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
