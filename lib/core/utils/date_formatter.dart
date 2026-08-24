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

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
}
