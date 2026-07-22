import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../theme/theme_colors.dart';

class UpcomingAddaCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool isFollowing;
  final bool isOwnRoom;
  final VoidCallback onToggleBell;
  final VoidCallback? onDelete;
  final VoidCallback? onStartNow;

  const UpcomingAddaCard({
    super.key,
    required this.room,
    required this.isFollowing,
    this.isOwnRoom = false,
    required this.onToggleBell,
    this.onDelete,
    this.onStartNow,
  });

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatScheduledTime(dynamic dateStr) {
    final d = _parseDate(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day;

    final timeStr = DateFormat('h:mm a').format(d);
    if (isToday) return 'Today · $timeStr';
    if (isTomorrow) return 'Tomorrow · $timeStr';
    return '${DateFormat('MMM d').format(d)} · $timeStr';
  }

  String? _getTimeUntil(dynamic dateStr) {
    final d = _parseDate(dateStr);
    if (d == null) return null;
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'Starting soon';
    if (diff.inDays >= 1) return 'in ${diff.inDays}D';
    if (diff.inHours > 0) return 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'in ${diff.inMinutes}m';
  }

  String _getUrgency(dynamic dateStr) {
    final d = _parseDate(dateStr);
    if (d == null) return 'normal';
    final diff = d.difference(DateTime.now());
    if (diff.isNegative || diff.inHours < 1) return 'urgent';
    if (diff.inHours < 3) return 'soon';
    return 'normal';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isCommunityAdda = room['group_id'] != null && room['group_id'].toString().isNotEmpty;
    final scheduledAt = room['scheduled_at'];
    final timeUntil = _getTimeUntil(scheduledAt);
    final urgency = _getUrgency(scheduledAt);

    final Color accentColor = isCommunityAdda
        ? const Color(0xFF7C3AED)
        : (urgency == 'urgent'
            ? const Color(0xFFFF3B30)
            : (urgency == 'soon'
                ? const Color(0xFFFF9F0A)
                : c.primary));

    final Color cardBg = isCommunityAdda
        ? (isDark ? const Color(0xFF7C3AED).withOpacity(0.10) : const Color(0xFF7C3AED).withOpacity(0.06))
        : (urgency == 'urgent'
            ? (isDark ? const Color(0xFFFF3B30).withOpacity(0.10) : const Color(0xFFFF3B30).withOpacity(0.06))
            : (urgency == 'soon'
                ? (isDark ? const Color(0xFFFF9F0A).withOpacity(0.10) : const Color(0xFFFF9F0A).withOpacity(0.06))
                : (isDark ? c.primary.withOpacity(0.10) : c.primary.withOpacity(0.06))));

    final displayName = isCommunityAdda
        ? (room['group_name']?.toString() ?? 'Community')
        : (room['host_name']?.toString() ?? room['host_username']?.toString() ?? 'Host');

    final avatarUri = isCommunityAdda
        ? room['group_picture']?.toString()
        : room['host_profile_pic']?.toString();

    final avatarIcon = isCommunityAdda ? Icons.group : Icons.person;
    final roomName = room['room_name']?.toString() ?? 'Scheduled Adda';
    final topic = room['topic']?.toString();

    return GestureDetector(
      onTap: isOwnRoom ? onStartNow : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.primary.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Community/Topic badge (left) + TimeUntil badge (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isCommunityAdda)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group, size: 11, color: Color(0xFF7C3AED)),
                                SizedBox(width: 3),
                                Text(
                                  'Community',
                                  style: TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (topic != null && topic.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accentColor.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.forum, size: 12, color: accentColor),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      topic,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Outfit',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (timeUntil != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 11, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            timeUntil,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Room Name
              Text(
                roomName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.29,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Schedule Time Row
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.event, size: 14, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatScheduledTime(scheduledAt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      color: accentColor,
                    ),
                  ),
                ],
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: accentColor.withOpacity(0.13),
              ),

              // Footer: Host/Group + Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.primary.withOpacity(0.27), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: avatarUri != null && avatarUri.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUri,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: accentColor.withOpacity(0.12),
                                      alignment: Alignment.center,
                                      child: Icon(avatarIcon, size: 13, color: accentColor),
                                    ),
                                  )
                                : Container(
                                    color: accentColor.withOpacity(0.12),
                                    alignment: Alignment.center,
                                    child: Icon(avatarIcon, size: 13, color: accentColor),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayName,
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
                      ],
                    ),
                  ),

                  if (!isOwnRoom && !isCommunityAdda)
                    GestureDetector(
                      onTap: onToggleBell,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isFollowing ? c.primary : c.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFollowing ? c.primary : c.primary.withOpacity(0.22),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing ? Icons.notifications : Icons.notifications_none,
                              size: 16,
                              color: isFollowing ? Colors.white : accentColor,
                            ),
                            if (isFollowing) ...[
                              const SizedBox(width: 5),
                              const Text(
                                'Notifying',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  if (isOwnRoom)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                'Your Adda',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.22), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF6B6B)),
                            ),
                          ),
                        ],
                      ],
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
