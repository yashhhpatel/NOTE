import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/notes/checklist_editor.dart';
import '../../features/notes/text_note_editor.dart';
import '../../features/settings/settings_screen.dart';

/// Route paths used across the app for type-safe navigation.
class Routes {
  const Routes._();
  static const home = '/';
  static const settings = '/settings';

  static String textNote(String id) => '/note/$id';
  static String checklist(String id) => '/checklist/$id';
}

/// Central go_router configuration. Deep links (e.g. from reminder
/// notifications) will be added to this tree in later phases.
final appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'note/:id',
          builder: (context, state) =>
              TextNoteEditor(noteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'checklist/:id',
          builder: (context, state) =>
              ChecklistEditor(noteId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
