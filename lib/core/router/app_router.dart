import 'package:go_router/go_router.dart';

import '../../features/archive/archive_screen.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notes/checklist_editor.dart';
import '../../features/notes/text_note_editor.dart';
import '../../features/search/search_screen.dart';
import '../../features/security/security_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/trash/trash_screen.dart';

/// Route paths used across the app for type-safe navigation.
class Routes {
  const Routes._();
  static const home = '/';
  static const settings = '/settings';
  static const search = '/search';
  static const categories = '/categories';
  static const archive = '/archive';
  static const trash = '/trash';
  static const calendar = '/calendar';
  static const security = '/security';
  static const backup = '/backup';

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
          path: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
        GoRoute(
          path: 'archive',
          builder: (context, state) => const ArchiveScreen(),
        ),
        GoRoute(
          path: 'trash',
          builder: (context, state) => const TrashScreen(),
        ),
        GoRoute(
          path: 'calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: 'security',
          builder: (context, state) => const SecuritySettingsScreen(),
        ),
        GoRoute(
          path: 'backup',
          builder: (context, state) => const BackupScreen(),
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
