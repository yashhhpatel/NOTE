import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/enums.dart';
import 'features/settings/settings_providers.dart';

/// Root widget. Watches persisted preferences so the theme reflects the
/// user's saved choice as soon as it loads.
class NoteflowApp extends ConsumerWidget {
  const NoteflowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final themeMode = prefs.maybeWhen(
      data: (p) => p.materialThemeMode,
      orElse: () => AppThemeMode.system.index == 0
          ? ThemeMode.system
          : ThemeMode.system,
    );

    return MaterialApp.router(
      title: 'Noteflow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
