import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../theme/theme_colors.dart';

class UpcomingAddaCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool isFollowing;
  final VoidCallback onToggleBell;

  const UpcomingAddaCard({
    super.key,
    required this.room,
    required this.isFollowing,
    required this.onToggleBell,
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
    final topic = room['topic']?.toString() ?? room['room_name']?.toString() ?? 'Scheduled Adda';
    final hostName = room['host_name']?.toString() ?? room['host_username']?.toString() ?? 'Host';
    final hostPic = room['host_profile_pic']?.toString();
    final scheduledAt = room['scheduled_at'];

    final scheduledText = _formatScheduledTime(scheduledAt);
    final countdownText = _getTimeUntil(scheduledAt);
    final urgency = _getUrgency(scheduledAt);

    Color badgeBg = Colors.blue.withOpacity(0.15);
    Color badgeText = Colors.blue;
    if (urgency == 'urgent') {
      badgeBg = Colors.red.withOpacity(0.15);
      badgeText = Colors.red;
    } else if (urgency == 'soon') {
      badgeBg = Colors.orange.withOpacity(0.15);
      badgeText = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 12, color: badgeText),
                    const SizedBox(width: 4),
                    Text(
                      scheduledText,
                      style: TextStyle(
                        color: badgeText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              if (countdownText != null) ...[
                const SizedBox(width: 8),
                Text(
                  countdownText,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
              const Spacer(),
              // Bell Notify Button
              IconButton(
                onPressed: onToggleBell,
                icon: Icon(
                  isFollowing ? Icons.notifications_active : Icons.notifications_none,
                  color: isFollowing ? c.primaryButton : c.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            topic,
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: c.border,
                backgroundImage: hostPic != null && hostPic.isNotEmpty
                    ? CachedNetworkImageProvider(hostPic)
                    : null,
                child: hostPic == null || hostPic.isEmpty
                    ? Text(
                        hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
                        style: TextStyle(color: c.text, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                hostName,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
