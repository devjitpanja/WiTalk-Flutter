import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';
import 'wave_bar_anim.dart';
import 'animated_tag_border.dart';

const Map<String, IconData> _iconMap = {
  'star': Icons.star,
  'award': Icons.emoji_events,
  'shield-check': Icons.verified_user,
  'crown': Icons.workspace_premium,
  'zap': Icons.bolt,
  'flame': Icons.local_fire_department,
  'sparkles': Icons.auto_awesome,
  'badge-check': Icons.verified,
  'badge': Icons.badge,
  'heart': Icons.favorite,
  'mic': Icons.mic,
  'music': Icons.music_note,
  'globe': Icons.language,
  'lock': Icons.lock,
  'tag': Icons.label,
};

class PersonalAddaCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final int paletteIndex;
  final Function(Map<String, dynamic> room) onJoinRoom;

  const PersonalAddaCard({
    super.key,
    required this.room,
    required this.paletteIndex,
    required this.onJoinRoom,
  });

  static const List<Map<String, dynamic>> cardPalettes = [
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFD1FAE5)],
      'gradientDark': [Color(0xFF0C1F12), Color(0xFF0C1F12), Color(0xFF0A2A17)],
      'border': Color(0xFF22C55E),
      'accent': Color(0xFF16A34A),
      'accentLight': Color(0xFF4ADE80),
      'joinGradient': [Color(0xFF16A34A), Color(0xFF22C55E)],
    },
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFEDE9FE)],
      'gradientDark': [Color(0xFF170D2A), Color(0xFF170D2A), Color(0xFF1E1038)],
      'border': Color(0xFFA855F7),
      'accent': Color(0xFF7C3AED),
      'accentLight': Color(0xFFC084FC),
      'joinGradient': [Color(0xFF7C3AED), Color(0xFFA855F7)],
    },
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFED7AA)],
      'gradientDark': [Color(0xFF1F1208), Color(0xFF1F1208), Color(0xFF291608)],
      'border': Color(0xFFF97316),
      'accent': Color(0xFFEA580C),
      'accentLight': Color(0xFFFB923C),
      'joinGradient': [Color(0xFFEA580C), Color(0xFFF97316)],
    },
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFDBEAFE)],
      'gradientDark': [Color(0xFF071523), Color(0xFF071523), Color(0xFF071F30)],
      'border': Color(0xFF3B82F6),
      'accent': Color(0xFF2563EB),
      'accentLight': Color(0xFF60A5FA),
      'joinGradient': [Color(0xFF2563EB), Color(0xFF3B82F6)],
    },
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFECDD3)],
      'gradientDark': [Color(0xFF1A0509), Color(0xFF1A0509), Color(0xFF240710)],
      'border': Color(0xFFF43F5E),
      'accent': Color(0xFFE11D48),
      'accentLight': Color(0xFFFB7185),
      'joinGradient': [Color(0xFFE11D48), Color(0xFFF43F5E)],
    },
    {
      'gradientLight': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFCCFBF1)],
      'gradientDark': [Color(0xFF061C18), Color(0xFF061C18), Color(0xFF07241E)],
      'border': Color(0xFF14B8A6),
      'accent': Color(0xFF0D9488),
      'accentLight': Color(0xFF2DD4BF),
      'joinGradient': [Color(0xFF0D9488), Color(0xFF14B8A6)],
    },
  ];

  static const Map<String, dynamic> communityPalette = {
    'gradientLight': [Color(0xFFFFFFFF), Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
    'gradientDark': [Color(0xFF130828), Color(0xFF18093E), Color(0xFF1E1048)],
    'border': Color(0xFF8B5CF6),
    'accent': Color(0xFF7C3AED),
    'accentLight': Color(0xFFA78BFA),
    'joinGradient': [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
  };

  Color _parseHexColor(String? hexStr, Color fallback) {
    if (hexStr == null || hexStr.isEmpty) return fallback;
    try {
      var cleanStr = hexStr.replaceAll('#', '');
      if (cleanStr.length == 6) cleanStr = 'FF$cleanStr';
      if (cleanStr.length == 8) {
        return Color(int.parse(cleanStr, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isCommunityAdda = room['group_id'] != null && room['group_id'].toString().isNotEmpty;
    final isPublic = room['is_public'] == true || room['is_public'] == 1 || room['is_public'] == null;
    final basePalette = isCommunityAdda
        ? communityPalette
        : cardPalettes[paletteIndex % cardPalettes.length];

    final tags = (room['tags'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasTags = tags.isNotEmpty;
    final primaryTag = hasTags ? tags.first : null;

    Map<String, dynamic> effectivePalette = basePalette;
    if (hasTags && primaryTag != null && !isCommunityAdda) {
      final tagColorHex = primaryTag['color']?.toString();
      final tagColor = _parseHexColor(tagColorHex, basePalette['border'] as Color);
      final isFilled = primaryTag['filled_bg'] == true || primaryTag['filled_bg'] == 1;

      effectivePalette = {
        'gradientLight': [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), tagColor.withOpacity(0.16)],
        'gradientDark': [
          (basePalette['gradientDark'] as List<Color>)[0],
          (basePalette['gradientDark'] as List<Color>)[1],
          tagColor.withOpacity(0.22),
        ],
        'border': tagColor,
        'accent': tagColor,
        'accentLight': tagColor,
        'joinGradient': isFilled ? [tagColor, tagColor] : [tagColor.withOpacity(0.8), tagColor],
      };
    }

    final gradientColors = (isDark ? effectivePalette['gradientDark'] : effectivePalette['gradientLight']) as List<Color>;
    final accent = (isDark ? effectivePalette['accentLight'] : effectivePalette['accent']) as Color;
    final borderColor = effectivePalette['border'] as Color;
    final joinGradient = effectivePalette['joinGradient'] as List<Color>;

    final totalRatings = room['total_ratings'] as int? ?? 0;
    final averageRating = room['average_rating'];
    final hasRating = totalRatings > 0 && averageRating != null;
    final ratingDisplay = hasRating
        ? double.tryParse(averageRating.toString())?.toStringAsFixed(1) ?? '🌱 New Adda'
        : '🌱 New Adda';

    final participantCount = (room['current_participants_count'] as int?) ?? 0;
    final rawParticipants = (room['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Dedup participants by id
    final seenIds = <String>{};
    final participants = <Map<String, dynamic>>[];
    for (final p in rawParticipants) {
      final pid = p['id']?.toString() ?? p['uid']?.toString() ?? '';
      if (pid.isEmpty || !seenIds.contains(pid)) {
        if (pid.isNotEmpty) seenIds.add(pid);
        participants.add(p);
      }
    }
    final extraCount = math.max(0, participantCount - 3);

    final roomName = room['room_name']?.toString() ?? 'Untitled Adda';
    final topic = room['topic']?.toString();
    final language = room['language']?.toString();

    final hostDisplayName = room['host_name']?.toString() ?? room['host_username']?.toString() ?? 'Host';
    final hostPic = room['host_profile_pic']?.toString();

    Widget cardInnerContent = GestureDetector(
      onTap: () => onJoinRoom(room),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: hasTags ? null : Border.all(color: borderColor.withOpacity(0.33)),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Badges (left) + Vibe/Rating (right) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isCommunityAdda && isPublic) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group, size: 11, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Community',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (room['group_name'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (room['group_picture'] != null && room['group_picture'].toString().isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: CachedNetworkImage(
                                      imageUrl: room['group_picture'].toString(),
                                      width: 14,
                                      height: 14,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  const Icon(Icons.group, size: 11, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Text(
                                  room['group_name'].toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language, size: 11, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Personal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (!isPublic)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 9, color: Color(0xFFFF9800)),
                              SizedBox(width: 3),
                              Text(
                                'Private',
                                style: TextStyle(
                                  color: Color(0xFFFF9800),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Admin Tag Pills
                      ...tags.map((tag) {
                        final colorHex = tag['color']?.toString();
                        final tColor = _parseHexColor(colorHex, accent);
                        final isFilled = tag['filled_bg'] == true || tag['filled_bg'] == 1;
                        final textColorHex = tag['text_color']?.toString();
                        final fg = _parseHexColor(textColorHex, isFilled ? Colors.white : tColor);
                        final pillBg = isFilled ? tColor : tColor.withOpacity(0.10);
                        final pillBorder = isFilled ? tColor : tColor.withOpacity(0.27);
                        final iconStr = tag['icon']?.toString();
                        final iconData = iconStr != null ? _iconMap[iconStr] : null;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9.5, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (iconData != null) ...[
                                Icon(iconData, size: 10, color: fg),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                tag['name']?.toString() ?? '',
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Vibe / Rating Badge
                GestureDetector(
                  onTap: () {
                    if (hasRating) {
                      context.push('/adda-reviews', extra: room);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ratingDisplay,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.star, size: 10, color: accent),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Room Name + Sound Wave Row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    roomName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      height: 1.33,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      7,
                      (idx) => WaveBar(index: idx, color: borderColor, height: 22),
                    ),
                  ),
                ),
              ],
            ),

            // ── Meta chips: CATEGORY & LANGUAGE ──
            if ((!isCommunityAdda && topic != null && topic.isNotEmpty) || (language != null && language.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!isCommunityAdda && topic != null && topic.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor.withOpacity(0.19)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CATEGORY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.38),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              topic,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                                color: accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isCommunityAdda && topic != null && topic.isNotEmpty && language != null && language.isNotEmpty)
                    const SizedBox(width: 8),
                  if (language != null && language.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor.withOpacity(0.19)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANGUAGE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.38),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              language,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                                color: accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 10),
              color: borderColor.withOpacity(0.16),
            ),

            // ── Footer: Host (left) + Participant cluster & listener count (right) ──
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Host Info
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor.withOpacity(0.38), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: hostPic != null && hostPic.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: hostPic,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: accent.withOpacity(0.13),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.person, size: 13, color: accent),
                                    ),
                                  )
                                : Container(
                                    color: accent.withOpacity(0.13),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.person, size: 13, color: accent),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  hostDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                    color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF1A1A2E).withOpacity(0.8),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Cluster: Avatar stack + listener count
                  Row(
                    children: [
                      if (participants.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final visibleCount = math.min(3, participants.length);
                            final totalBadges = visibleCount + (extraCount > 0 ? 1 : 0);
                            final stackWidth = 26.0 + (totalBadges - 1) * 16.0;
                            return SizedBox(
                              width: stackWidth,
                              height: 26,
                              child: Stack(
                                children: [
                                  for (int i = 0; i < visibleCount; i++) ...[
                                    Positioned(
                                      left: i * 16.0,
                                      top: 0,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(13),
                                          child: () {
                                            final p = participants[i];
                                            final pic = p['profile_pic']?.toString() ?? p['avatar']?.toString() ?? p['picture']?.toString();
                                            if (pic != null && pic.isNotEmpty) {
                                              return CachedNetworkImage(
                                                imageUrl: pic,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => Container(
                                                  color: accent.withOpacity(0.15),
                                                  child: Icon(Icons.person, size: 10, color: accent),
                                                ),
                                              );
                                            }
                                            return Container(
                                              color: accent.withOpacity(0.15),
                                              child: Icon(Icons.person, size: 10, color: accent),
                                            );
                                          }(),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (extraCount > 0)
                                    Positioned(
                                      left: visibleCount * 16.0,
                                      top: 0,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accent.withOpacity(0.18),
                                          border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '+$extraCount',
                                          style: TextStyle(
                                            color: accent,
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

                      if (participantCount > 0) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.headset, size: 11, color: accent),
                              const SizedBox(width: 4),
                              Text(
                                '$participantCount',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
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
    );

    Widget cardBody = hasTags
        ? AnimatedTagBorder(
            color: borderColor,
            bgColor: gradientColors.first,
            child: cardInnerContent,
          )
        : cardInnerContent;

    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          cardBody,

          // ── Floating Join Button at bottom right ──
          Positioned(
            bottom: -14,
            right: 20,
            child: GestureDetector(
              onTap: () => onJoinRoom(room),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: joinGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: joinGradient.first.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headset, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Join',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
