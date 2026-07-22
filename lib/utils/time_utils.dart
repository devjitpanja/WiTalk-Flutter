import 'package:intl/intl.dart';

/// Parse a MySQL DATETIME string (no timezone info) as UTC.
/// "2025-01-15 10:30:00" → DateTime in UTC
DateTime? parseDBDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    // Already has timezone info — parse as-is
    if (dateStr.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(dateStr)) {
      return DateTime.parse(dateStr);
    }
    // MySQL bare string: replace space separator, append Z for UTC
    return DateTime.parse('${dateStr.replaceFirst(' ', 'T')}Z');
  } catch (_) {
    return null;
  }
}

/// Relative time: "just now" / "5 min ago" / "3h ago" / "2d ago" / "15 Jan 2025"
String formatTimeAgo(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final date = parseDBDate(dateStr);
  if (date == null) return '';

  final diff = DateTime.now().difference(date.toLocal());
  final secs = diff.inSeconds;

  if (secs < 60) return 'just now';
  if (secs < 3600) return '${diff.inMinutes} min ago';
  if (secs < 86400) return '${diff.inHours}h ago';
  if (secs < 604800) return '${diff.inDays}d ago';
  if (secs < 2592000) return '${(diff.inDays / 7).floor()}w ago';

  return DateFormat('d MMM yyyy').format(date.toLocal());
}

/// Compact chat-list time: "just now" / "5m" / "3h" / "Yesterday" / "2d" / locale date
String formatChatListTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final date = parseDBDate(dateStr);
  if (date == null) return '';

  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  final secs = diff.inSeconds;

  if (secs < 60) return 'just now';
  if (secs < 3600) return '${diff.inMinutes}m';
  if (secs < 86400) return '${diff.inHours}h';

  final msgDay = DateFormat('yyyy-MM-dd').format(local);
  final todayDay = DateFormat('yyyy-MM-dd').format(now);
  final yesterdayDay = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

  if (msgDay == todayDay) return '${diff.inHours}h';
  if (msgDay == yesterdayDay) return 'Yesterday';

  final days = diff.inDays;
  if (days < 7) return '${days}d';

  return DateFormat.yMd().format(local);
}

/// "10:30 AM" — message bubble timestamp
String formatMessageTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final date = parseDBDate(dateStr);
  if (date == null) return '';
  return DateFormat('h:mm a').format(date.toLocal());
}

/// "Today" / "Yesterday" / "January 15, 2025" — chat date divider
String formatDateDivider(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final date = parseDBDate(dateStr);
  if (date == null) return '';

  final local = date.toLocal();
  final now = DateTime.now();
  final msgDay = DateFormat('yyyy-MM-dd').format(local);
  final todayDay = DateFormat('yyyy-MM-dd').format(now);
  final yesterdayDay = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

  if (msgDay == todayDay) return 'Today';
  if (msgDay == yesterdayDay) return 'Yesterday';

  return DateFormat('MMMM d, yyyy').format(local);
}

/// Last-seen string. Accepts DateTime, int (Unix ms), or MySQL string.
String formatLastSeen(dynamic timestamp) {
  if (timestamp == null) return 'last seen a long time ago';

  DateTime? date;
  if (timestamp is DateTime) {
    date = timestamp;
  } else if (timestamp is int) {
    date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  } else if (timestamp is String) {
    date = parseDBDate(timestamp);
  }

  if (date == null || date.millisecondsSinceEpoch == 0) {
    return 'last seen a long time ago';
  }

  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.isNegative) return 'last seen just now';

  final secs = diff.inSeconds;
  final mins = diff.inMinutes;

  if (secs < 60) return 'last seen just now';
  if (mins < 60) return 'last seen ${mins == 1 ? '1 minute' : '$mins minutes'} ago';

  final timeStr = DateFormat('h:mm a').format(local);
  final msgDay = DateFormat('yyyy-MM-dd').format(local);
  final todayDay = DateFormat('yyyy-MM-dd').format(now);
  final yesterdayDay = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

  if (msgDay == todayDay) return 'last seen today at $timeStr';
  if (msgDay == yesterdayDay) return 'last seen yesterday at $timeStr';

  final days = diff.inDays;
  if (days < 7) return 'last seen $days days ago';

  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yy = local.year.toString().substring(2);
  return 'last seen $dd.$mm.$yy';
}

/// "Joined today" / "Joined 3 days ago" / "Joined 2 months ago"
String formatJoinedDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'Recently joined';
  final date = parseDBDate(dateStr);
  if (date == null) return 'Recently joined';

  final days = DateTime.now().difference(date.toLocal()).inDays;

  if (days == 0) return 'Joined today';
  if (days == 1) return 'Joined yesterday';
  if (days < 30) return 'Joined $days days ago';
  if (days < 365) {
    final months = (days / 30).floor();
    return 'Joined ${months == 1 ? '1 month' : '$months months'} ago';
  }
  final years = (days / 365).floor();
  return 'Joined ${years == 1 ? '1 year' : '$years years'} ago';
}
