import 'entities/enums.dart';

/// Pure date math for reminder scheduling. Kept free of Flutter/plugin
/// dependencies so it is fully unit-testable.
class ReminderScheduling {
  const ReminderScheduling._();

  /// Computes the next occurrence of a reminder strictly after [after].
  ///
  /// - For [ReminderRepeat.none], returns [base] if it is after [after],
  ///   otherwise null (the one-time reminder has passed).
  /// - For recurring reminders, advances [base] by the repeat interval until
  ///   it is strictly after [after].
  static DateTime? nextOccurrence({
    required DateTime base,
    required ReminderRepeat repeat,
    int? customIntervalDays,
    required DateTime after,
  }) {
    if (repeat == ReminderRepeat.none) {
      return base.isAfter(after) ? base : null;
    }

    var next = base;
    // Guard against pathological inputs; each branch always advances.
    var safety = 0;
    while (!next.isAfter(after) && safety < 10000) {
      next = _advance(next, repeat, customIntervalDays);
      safety++;
    }
    return next;
  }

  static DateTime _advance(
    DateTime dt,
    ReminderRepeat repeat,
    int? customIntervalDays,
  ) {
    switch (repeat) {
      case ReminderRepeat.daily:
        return dt.add(const Duration(days: 1));
      case ReminderRepeat.weekly:
        return dt.add(const Duration(days: 7));
      case ReminderRepeat.monthly:
        return _addMonths(dt, 1);
      case ReminderRepeat.custom:
        final days = (customIntervalDays == null || customIntervalDays < 1)
            ? 1
            : customIntervalDays;
        return dt.add(Duration(days: days));
      case ReminderRepeat.none:
        return dt; // Unreachable; handled by caller.
    }
  }

  /// Adds [months] calendar months, clamping the day to the target month's
  /// length (e.g. Jan 31 + 1 month = Feb 28/29).
  static DateTime _addMonths(DateTime dt, int months) {
    final totalMonth = dt.month - 1 + months;
    final year = dt.year + totalMonth ~/ 12;
    final month = totalMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = dt.day < lastDay ? dt.day : lastDay;
    return DateTime(
        year, month, day, dt.hour, dt.minute, dt.second);
  }
}
