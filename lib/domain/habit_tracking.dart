/// Pure date/streak math for habit-mode checklists. Kept free of Flutter/DB
/// dependencies so it is fully unit-testable.
class HabitTracking {
  const HabitTracking._();

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Call whenever a checklist's completion state changes. If [allChecked] is
  /// true and the streak wasn't already counted for [now]'s date, extends the
  /// streak (by 1 if the last completion was yesterday, otherwise restarts it
  /// at 1). Returns the streak/last-completed-date to persist, or null if
  /// nothing changes (not fully checked, or already counted today).
  static ({int streak, DateTime lastCompletedDate})? onItemsChanged({
    required bool allChecked,
    required DateTime now,
    required int currentStreak,
    required DateTime? lastCompletedDate,
  }) {
    if (!allChecked) return null;
    final today = _dateOnly(now);
    if (lastCompletedDate != null && _dateOnly(lastCompletedDate) == today) {
      return null; // Already counted today.
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final continuesStreak = lastCompletedDate != null &&
        _dateOnly(lastCompletedDate) == yesterday;
    return (
      streak: continuesStreak ? currentStreak + 1 : 1,
      lastCompletedDate: today,
    );
  }

  /// Call when a habit checklist is opened (or the app resumes). If a new
  /// calendar day has started since the last reset, decides whether the
  /// streak is broken (a day was missed) and that items should be unchecked.
  /// Returns null if no reset is due yet.
  static ({int streak, DateTime resetDate, bool shouldUncheckItems})?
      resetIfNewDay({
    required DateTime now,
    required DateTime? lastResetDate,
    required DateTime? lastCompletedDate,
    required int currentStreak,
  }) {
    final today = _dateOnly(now);
    if (lastResetDate != null && _dateOnly(lastResetDate) == today) {
      return null; // Already handled today.
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final missedADay = lastCompletedDate == null
        ? currentStreak > 0 // started but never completed once
        : _dateOnly(lastCompletedDate) != today &&
            _dateOnly(lastCompletedDate) != yesterday;
    return (
      streak: missedADay ? 0 : currentStreak,
      resetDate: today,
      shouldUncheckItems: true,
    );
  }
}
