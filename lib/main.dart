import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/services/consent_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/reminder_service.dart';
import 'features/notes/notes_providers.dart';
import 'features/reminders/reminders_providers.dart';

/// How long trashed notes are retained before automatic permanent deletion.
const kTrashRetention = Duration(days: 30);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final container = ProviderContainer();

  // Best-effort trash auto-cleanup; never blocks startup on failure.
  try {
    await container
        .read(notesRepositoryProvider)
        .purgeExpiredTrash(kTrashRetention);
  } catch (_) {}

  // Best-effort cleanup of empty notes orphaned by an abnormal exit (crash,
  // ANR, OS kill) before their own discard-if-empty logic could run.
  try {
    await container.read(notesRepositoryProvider).purgeOrphanedEmptyNotes();
  } catch (_) {}

  // Initialise local notifications and re-arm any active reminders (survives
  // reboots / process death). Kept on the startup path since a reminder tap
  // needs initialLaunchNoteId before the first frame.
  String? initialNoteId;
  try {
    await ReminderService.instance.init();
    await ReminderService.instance.rescheduleAll(
      container.read(remindersRepositoryProvider),
      container.read(databaseProvider),
    );
    initialNoteId = await ReminderService.instance.initialLaunchNoteId();
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: NoteflowApp(initialNoteId: initialNoteId),
    ),
  );

  // AdMob and the home-screen widget are non-critical: never let a slow or
  // misbehaving third-party SDK (observed: Google Play Services' transport
  // JobScheduler can stall on devices/emulators with outdated Play Services)
  // delay first paint or block the UI thread. Fired after runApp, not awaited.
  unawaited(_initNonCritical());
}

Future<void> _initNonCritical() async {
  // Runs the UMP consent flow (if required) and then initialises AdMob —
  // never awaited on the startup path; see ConsentService for the timeout/
  // fallback guarantees that keep this from ever blocking or hanging.
  try {
    await ConsentService.instance.requestConsentAndInitAds();
  } catch (_) {}
  try {
    await HomeWidgetService.instance.init();
  } catch (_) {}
}
