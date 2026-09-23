import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/local/database.dart';
import '../../data/repositories/reminders_repository.dart';
import '../../domain/entities/enums.dart';
import '../../domain/reminder_scheduling.dart';

/// Notification action identifiers.
class ReminderActions {
  static const complete = 'complete';
  static const snooze = 'snooze';
}

/// Manages local reminder notifications: scheduling, cancellation, recurrence
/// and the actions users can take from a notification. No network/backend.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _channelId = 'noteflow_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription = 'Note reminders and recurring alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Emits the noteId when the user taps a reminder (to open that note).
  final StreamController<String> _selectNoteController =
      StreamController<String>.broadcast();
  Stream<String> get onSelectNote => _selectNoteController.stream;

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to UTC if the platform timezone cannot be resolved.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    ));

    _initialised = true;
  }

  /// Requests notification + exact-alarm permissions (Android 13+/12+).
  /// Returns whether notifications are permitted.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? true;
    await android.requestExactAlarmsPermission();
    return granted;
  }

  /// If the app was launched by tapping a notification, returns its noteId.
  Future<String?> initialLaunchNoteId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return _payloadNoteId(details!.notificationResponse?.payload);
    }
    return null;
  }

  /// Schedules (or reschedules) a reminder's next occurrence.
  Future<void> schedule(
    Reminder reminder, {
    required String noteTitle,
    required String notePreview,
    bool enableSound = true,
    bool enableVibration = true,
  }) async {
    final next = ReminderScheduling.nextOccurrence(
      base: reminder.triggerAt,
      repeat: reminder.repeat,
      customIntervalDays: reminder.customIntervalDays,
      after: DateTime.now(),
    );
    if (next == null) {
      await cancel(reminder.notificationId);
      return;
    }

    final payload = jsonEncode({
      'note': reminder.noteId,
      'reminder': reminder.id,
    });
    final title = noteTitle.trim().isEmpty ? 'Reminder' : noteTitle.trim();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: enableSound,
      enableVibration: enableVibration,
      actions: const [
        AndroidNotificationAction(ReminderActions.complete, 'Complete',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction(ReminderActions.snooze, 'Snooze',
            showsUserInterface: false, cancelNotification: true),
      ],
    );

    await _plugin.zonedSchedule(
      reminder.notificationId,
      title,
      notePreview,
      tz.TZDateTime.from(next, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: _matchComponents(reminder.repeat),
    );
  }

  Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);

  /// Re-schedules every active reminder to its next future occurrence. Call at
  /// app start and after reboot so alarms survive process death / restarts.
  Future<void> rescheduleAll(
    RemindersRepository reminders,
    AppDatabase db,
  ) async {
    final active = await reminders.getActive();
    for (final r in active) {
      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals(r.noteId)))
          .getSingleOrNull();
      if (note == null || note.trashed) {
        await cancel(r.notificationId);
        continue;
      }
      await schedule(r,
          noteTitle: note.title,
          notePreview: _preview(note));
    }
  }

  static DateTimeComponents? _matchComponents(ReminderRepeat repeat) {
    switch (repeat) {
      case ReminderRepeat.daily:
        return DateTimeComponents.time;
      case ReminderRepeat.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case ReminderRepeat.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case ReminderRepeat.custom:
      case ReminderRepeat.none:
        return null;
    }
  }

  void _onForegroundResponse(NotificationResponse response) {
    final noteId = _payloadNoteId(response.payload);
    final reminderId = _payloadReminderId(response.payload);
    switch (response.actionId) {
      case ReminderActions.complete:
        if (reminderId != null) {
          _handleCompleteInBackground(reminderId);
        }
      case ReminderActions.snooze:
        if (reminderId != null) {
          _handleSnoozeInBackground(
              reminderId, const Duration(minutes: 10));
        }
      default:
        if (noteId != null) _selectNoteController.add(noteId);
    }
  }

  Future<void> _handleCompleteInBackground(String reminderId) async {
    final db = AppDatabase();
    try {
      final repo = RemindersRepository(db);
      final next = await repo.completeOccurrence(reminderId);
      if (next != null) {
        final note = await (db.select(db.notes)
              ..where((t) => t.id.equals(next.noteId)))
            .getSingleOrNull();
        await instance.schedule(next,
            noteTitle: note?.title ?? '',
            notePreview: note == null ? '' : _preview(note));
      }
    } finally {
      await db.close();
    }
  }

  Future<void> _handleSnoozeInBackground(
      String reminderId, Duration by) async {
    final db = AppDatabase();
    try {
      final repo = RemindersRepository(db);
      final updated =
          await repo.snooze(reminderId, DateTime.now().add(by));
      if (updated != null) {
        final note = await (db.select(db.notes)
              ..where((t) => t.id.equals(updated.noteId)))
            .getSingleOrNull();
        await instance.schedule(updated,
            noteTitle: note?.title ?? '',
            notePreview: note == null ? '' : _preview(note));
      }
    } finally {
      await db.close();
    }
  }

  static String _preview(Note note) {
    if (note.type == NoteType.checklist) return 'Checklist reminder';
    final content = note.content.trim();
    if (content.isEmpty) return 'Note reminder';
    return content.length > 80 ? '${content.substring(0, 80)}…' : content;
  }

  static String? _payloadNoteId(String? payload) =>
      _payloadField(payload, 'note');
  static String? _payloadReminderId(String? payload) =>
      _payloadField(payload, 'reminder');

  static String? _payloadField(String? payload, String key) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map[key] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Background isolate handler for notification actions (Complete/Snooze) when
/// the app is not in the foreground. Must be a top-level, entry-point function.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId != ReminderActions.complete &&
      actionId != ReminderActions.snooze) {
    return;
  }
  final payload = response.payload;
  if (payload == null) return;
  String? reminderId;
  try {
    reminderId = (jsonDecode(payload) as Map<String, dynamic>)['reminder']
        as String?;
  } catch (_) {
    return;
  }
  if (reminderId == null) return;

  // Fire-and-forget DB work in the background isolate.
  unawaited(_backgroundAction(actionId!, reminderId));
}

Future<void> _backgroundAction(String actionId, String reminderId) async {
  final db = AppDatabase();
  try {
    final repo = RemindersRepository(db);
    if (actionId == ReminderActions.complete) {
      await repo.completeOccurrence(reminderId);
    } else {
      await repo.snooze(reminderId, DateTime.now().add(const Duration(minutes: 10)));
    }
  } catch (_) {
    // Best effort; nothing to surface from a background isolate.
  } finally {
    await db.close();
  }
}
