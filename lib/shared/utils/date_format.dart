import 'package:intl/intl.dart';

/// Human-friendly relative/absolute formatting for note timestamps.
String formatNoteDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(that).inDays;

  if (diffDays == 0) return DateFormat.jm().format(date); // e.g. 3:04 PM
  if (diffDays == 1) return 'Yesterday';
  if (diffDays < 7) return DateFormat.EEEE().format(date); // weekday
  if (date.year == now.year) return DateFormat.MMMd().format(date); // Sep 22
  return DateFormat.yMMMd().format(date); // Sep 22, 2024
}
