import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/services/ads_service.dart';
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

  // Initialise local notifications and re-arm any active reminders (survives
  // reboots / process death).
  String? initialNoteId;
  try {
    await ReminderService.instance.init();
    await ReminderService.instance.rescheduleAll(
      container.read(remindersRepositoryProvider),
      container.read(databaseProvider),
    );
    initialNoteId = await ReminderService.instance.initialLaunchNoteId();
  } catch (_) {}

  // Initialise AdMob (best-effort; the app is fully usable if ads fail).
  try {
    await AdsService.instance.init();
  } catch (_) {}

  // Home-screen widget (best-effort; app shortcuts init in NoteflowApp's
  // initState so a cold start via shortcut is caught).
  try {
    await HomeWidgetService.instance.init();
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: NoteflowApp(initialNoteId: initialNoteId),
    ),
  );
}
