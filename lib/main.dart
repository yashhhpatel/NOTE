import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notes/notes_providers.dart';

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
  } catch (_) {
    // Ignore — cleanup will retry next launch.
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NoteflowApp(),
    ),
  );
}
