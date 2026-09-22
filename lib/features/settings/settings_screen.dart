import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/entities/enums.dart';
import 'settings_providers.dart';

/// Settings screen. In Phase 1 it hosts Appearance (theme) so that theme
/// persistence is verifiable end-to-end. Later phases add the remaining
/// sections (Notes, Notifications, Security, Backup, About).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings: $e')),
        data: (prefs) => ListView(
          children: [
            const _SectionHeader('Appearance'),
            RadioListTile<AppThemeMode>(
              title: const Text('System default'),
              value: AppThemeMode.system,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(ref, m),
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Light'),
              value: AppThemeMode.light,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(ref, m),
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Dark'),
              value: AppThemeMode.dark,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(ref, m),
            ),
            const Divider(),
            const _SectionHeader('Security'),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('App lock & biometrics'),
              subtitle: Text(prefs.appLockEnabled ? 'On' : 'Off'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.security),
            ),
          ],
        ),
      ),
    );
  }

  void _setTheme(WidgetRef ref, AppThemeMode? mode) {
    if (mode == null) return;
    ref.read(preferencesProvider.notifier).setThemeMode(mode);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
