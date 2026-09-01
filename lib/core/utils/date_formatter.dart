import 'package:intl/intl.dart';

/// Human-friendly relative and absolute date formatting for trips and expenses.
class DateFormatter {
  DateFormatter._();

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && date.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1 || (difference.inHours < 48 && date.day == now.day - 1)) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('d MMM, h:mm a').format(date);
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatShortDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    }
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  static String formatTripDateRange(DateTime start, [DateTime? end]) {
    if (end == null || start.isAtSameMomentAs(end)) {
      return DateFormat('MMM d, yyyy').format(start);
    }
    if (start.year == end.year) {
      if (start.month == end.month) {
        return '${DateFormat('MMM d').format(start)} – ${DateFormat('d, yyyy').format(end)}';
      }
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  /// Formats active trip started date: 'Started 24 Aug' or 'Started 24 Aug 2026'
  static String formatTripActiveDate(DateTime startedAt) {
    final now = DateTime.now();
    if (startedAt.year == now.year) {
      return 'Started ${DateFormat('d MMM').format(startedAt)}';
    }
    return 'Started ${DateFormat('d MMM yyyy').format(startedAt)}';
  }

  /// Formats completed trip historical range: '24 Aug → 27 Aug 2026' or '24 Aug 2026' if same day
  static String formatTripHistoricalRange(DateTime startedAt, DateTime? completedAt) {
    if (completedAt == null) {
      return formatTripActiveDate(startedAt);
    }
    final isSameDay = startedAt.year == completedAt.year &&
        startedAt.month == completedAt.month &&
        startedAt.day == completedAt.day;
    if (isSameDay) {
      return DateFormat('d MMM yyyy').format(startedAt);
    }
    if (startedAt.year == completedAt.year) {
      return '${DateFormat('d MMM').format(startedAt)} → ${DateFormat('d MMM yyyy').format(completedAt)}';
    }
    return '${DateFormat('d MMM yyyy').format(startedAt)} → ${DateFormat('d MMM yyyy').format(completedAt)}';
  }
}
