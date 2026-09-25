import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/archive/archive_screen.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/billing/remove_ads_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notes/checklist_editor.dart';
import '../../features/notes/text_note_editor.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/security/security_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/trash/trash_screen.dart';

/// Route paths used across the app for type-safe navigation.
class Routes {
  const Routes._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const search = '/search';
  static const categories = '/categories';
  static const archive = '/archive';
  static const trash = '/trash';
  static const calendar = '/calendar';
  static const security = '/security';
  static const backup = '/backup';
  static const removeAds = '/remove-ads';
  static const about = '/about';

  static String textNote(String id) => '/note/$id';
  static String checklist(String id) => '/checklist/$id';
}

/// Whether onboarding has been completed, cached here so the synchronous
/// `redirect` callback can read it without an async gap. `null` means "not
/// loaded yet" and the redirect is a no-op until [setOnboardingDone] runs
/// once preferences resolve (see NoteflowApp).
bool? _onboardingDoneCache;

/// Ticking this notifies go_router to re-run `redirect`.
final ValueNotifier<bool> onboardingRefresh = ValueNotifier(false);

/// Called once preferences load (and again whenever onboarding completes) so
/// the router's redirect reflects the current state.
void setOnboardingDone(bool done) {
  if (_onboardingDoneCache == done) return;
  _onboardingDoneCache = done;
  onboardingRefresh.value = !onboardingRefresh.value;
}

/// Central go_router configuration. Deep links (e.g. from reminder
/// notifications, app shortcuts) push routes directly via [appRouter].
final appRouter = GoRouter(
  initialLocation: Routes.home,
  refreshListenable: onboardingRefresh,
  redirect: (context, state) {
    final done = _onboardingDoneCache;
    if (done == null) return null; // Not loaded yet; don't redirect blindly.
    final atOnboarding = state.matchedLocation == Routes.onboarding;
    if (!done && !atOnboarding) return Routes.onboarding;
    if (done && atOnboarding) return Routes.home;
    return null;
  },
  routes: [
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
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
          path: 'remove-ads',
          builder: (context, state) => const RemoveAdsScreen(),
        ),
        GoRoute(
          path: 'about',
          builder: (context, state) => const AboutScreen(),
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
