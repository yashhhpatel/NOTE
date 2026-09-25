import 'dart:async';

import 'package:quick_actions/quick_actions.dart';

/// Long-press-launcher-icon shortcuts: "New text note" and "New checklist".
/// Both reuse the launcher icon (no extra art assets needed). Purely local —
/// Android's own ShortcutManager, no network involved.
///
/// [init] must be called from the root widget's `initState` (not `main()`) so
/// the callback is registered in time to receive the action that cold-started
/// the app, matching the plugin's documented usage.
class AppShortcutsService {
  AppShortcutsService._();
  static final AppShortcutsService instance = AppShortcutsService._();

  static const newTextNote = 'new_text_note';
  static const newChecklist = 'new_checklist';

  final QuickActions _quickActions = const QuickActions();
  final _controller = StreamController<String>.broadcast();

  /// Emits the shortcut type whenever one is chosen (live tap or cold start).
  Stream<String> get onAction => _controller.stream;

  Future<void> init() async {
    _quickActions.initialize((type) => _controller.add(type));
    await _quickActions.setShortcutItems(const [
      ShortcutItem(
        type: newTextNote,
        localizedTitle: 'New text note',
        icon: 'ic_launcher',
      ),
      ShortcutItem(
        type: newChecklist,
        localizedTitle: 'New checklist',
        icon: 'ic_launcher',
      ),
    ]);
  }
}
