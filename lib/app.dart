import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/enums.dart';
import 'features/notes/notes_providers.dart';
import 'features/security/app_lock_gate.dart';
import 'features/settings/settings_providers.dart';

/// Root widget. Watches persisted preferences for theming and routes reminder
/// notification taps to the relevant note.
class NoteflowApp extends ConsumerStatefulWidget {
  const NoteflowApp({super.key, this.initialNoteId});

  /// Note to open if the app was launched by tapping a reminder.
  final String? initialNoteId;

  @override
  ConsumerState<NoteflowApp> createState() => _NoteflowAppState();
}

class _NoteflowAppState extends ConsumerState<NoteflowApp> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ReminderService.instance.onSelectNote.listen(_openNote);
    final initial = widget.initialNoteId;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNote(initial));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openNote(String noteId) async {
    final note = await ref.read(notesRepositoryProvider).getNote(noteId);
    if (note == null) return;
    appRouter.push(
      note.type == NoteType.checklist
          ? Routes.checklist(noteId)
          : Routes.textNote(noteId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final themeMode = prefs.maybeWhen(
      data: (p) => p.materialThemeMode,
      orElse: () => ThemeMode.system,
    );

    return MaterialApp.router(
      title: 'Noteflow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
