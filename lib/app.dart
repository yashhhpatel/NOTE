import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/app_shortcuts_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/enums.dart';
import 'features/notes/notes_providers.dart';
import 'features/security/app_lock_gate.dart';
import 'features/settings/settings_providers.dart';

/// Root widget. Watches persisted preferences for theming, routes reminder
/// notification taps and app-shortcut taps to the relevant note/editor, and
/// keeps the home-screen widget's data in sync with the active notes list.
class NoteflowApp extends ConsumerStatefulWidget {
  const NoteflowApp({super.key, this.initialNoteId});

  /// Note to open if the app was launched by tapping a reminder.
  final String? initialNoteId;

  @override
  ConsumerState<NoteflowApp> createState() => _NoteflowAppState();
}

class _NoteflowAppState extends ConsumerState<NoteflowApp> {
  StreamSubscription<String>? _reminderSub;
  StreamSubscription<String>? _shortcutSub;

  @override
  void initState() {
    super.initState();
    _reminderSub = ReminderService.instance.onSelectNote.listen(_openNote);
    final initial = widget.initialNoteId;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNote(initial));
    }

    // Registered here (not main()) so a cold start via shortcut is caught.
    _shortcutSub =
        AppShortcutsService.instance.onAction.listen(_handleShortcut);
    AppShortcutsService.instance.init();

    // Resolve the router's onboarding redirect for the first time. Deferred
    // to a post-frame callback (not called inline during build) since
    // updating the refresh Listenable can synchronously notify go_router,
    // which must never happen while a build is in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await ref.read(preferencesProvider.future);
      setOnboardingDone(prefs.onboardingDone);
    });
  }

  @override
  void dispose() {
    _reminderSub?.cancel();
    _shortcutSub?.cancel();
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

  Future<void> _handleShortcut(String type) async {
    final repo = ref.read(notesRepositoryProvider);
    final isChecklist = type == AppShortcutsService.newChecklist;
    if (type != AppShortcutsService.newTextNote && !isChecklist) return;
    final note = await repo.createNote(
      type: isChecklist ? NoteType.checklist : NoteType.text,
    );
    appRouter.push(
      isChecklist ? Routes.checklist(note.id) : Routes.textNote(note.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final themeMode = prefs.maybeWhen(
      data: (p) => p.materialThemeMode,
      orElse: () => ThemeMode.system,
    );

    // Keep the router's onboarding redirect in sync with later changes (the
    // initial value is handled once in initState's post-frame callback).
    // ref.listen's callback runs outside the build phase, so this is safe.
    ref.listen(preferencesProvider, (previous, next) {
      next.whenData((p) => setOnboardingDone(p.onboardingDone));
    });

    // Keep the home-screen widget in sync with active/pinned notes whenever
    // the app is open. Kept at the app root so it updates regardless of
    // which screen is currently shown.
    ref.listen(activeNotesProvider, (previous, next) {
      next.whenData((cards) {
        final pinnedTitles = cards
            .where((c) => c.note.pinned)
            .map((c) => c.note.title.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        HomeWidgetService.instance
            .sync(activeCount: cards.length, pinnedTitles: pinnedTitles);
      });
    });

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
