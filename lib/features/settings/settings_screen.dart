import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/note_colors.dart';
import '../../domain/entities/enums.dart';
import '../../shared/widgets/color_picker_sheet.dart';
import 'settings_providers.dart';

/// The main Settings screen, organised into sections. Security, Backup and
/// About link to their own screens.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);

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
            // General ---------------------------------------------------------
            const _SectionHeader('General'),
            SwitchListTile(
              title: const Text('Grid view'),
              subtitle: const Text('Show notes in a two-column grid'),
              value: prefs.layout == NoteLayout.grid,
              onChanged: (v) => notifier
                  .setLayout(v ? NoteLayout.grid : NoteLayout.list),
            ),
            ListTile(
              title: const Text('Default new note'),
              subtitle: Text(prefs.defaultNoteType == NoteType.checklist
                  ? 'Checklist'
                  : 'Text note'),
              trailing: SegmentedButton<NoteType>(
                segments: const [
                  ButtonSegment(value: NoteType.text, label: Text('Text')),
                  ButtonSegment(
                      value: NoteType.checklist, label: Text('List')),
                ],
                selected: {prefs.defaultNoteType},
                onSelectionChanged: (s) =>
                    notifier.setDefaultNoteType(s.first),
              ),
            ),

            // Notes -----------------------------------------------------------
            const Divider(),
            const _SectionHeader('Notes'),
            SwitchListTile(
              title: const Text('Autosave while typing'),
              subtitle: const Text('Notes always save when you leave'),
              value: prefs.autosave,
              onChanged: notifier.setAutosave,
            ),
            SwitchListTile(
              title: const Text('Move completed items to bottom'),
              value: prefs.moveCheckedToBottom,
              onChanged: notifier.setMoveCheckedToBottom,
            ),
            ListTile(
              title: const Text('Default note colour'),
              trailing: CircleAvatar(
                backgroundColor: NoteColors.byId(prefs.defaultColorId)
                    .background(Theme.of(context).brightness),
                radius: 14,
              ),
              onTap: () async {
                final picked =
                    await showColorPicker(context, prefs.defaultColorId);
                if (picked != null) notifier.setDefaultColor(picked);
              },
            ),

            // Notifications ---------------------------------------------------
            const Divider(),
            const _SectionHeader('Notifications'),
            SwitchListTile(
              title: const Text('Sound'),
              value: prefs.notifSound,
              onChanged: notifier.setNotifSound,
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              value: prefs.notifVibration,
              onChanged: notifier.setNotifVibration,
            ),

            // Appearance ------------------------------------------------------
            const Divider(),
            const _SectionHeader('Appearance'),
            RadioListTile<AppThemeMode>(
              title: const Text('System default'),
              value: AppThemeMode.system,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(notifier, m),
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Light'),
              value: AppThemeMode.light,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(notifier, m),
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Dark'),
              value: AppThemeMode.dark,
              groupValue: prefs.themeMode,
              onChanged: (m) => _setTheme(notifier, m),
            ),

            // Security / Backup / About --------------------------------------
            const Divider(),
            const _SectionHeader('Security'),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('App lock & biometrics'),
              subtitle: Text(prefs.appLockEnabled ? 'On' : 'Off'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.security),
            ),
            const Divider(),
            const _SectionHeader('Backup'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & restore'),
              subtitle: const Text('Export or import your notes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.backup),
            ),
            const Divider(),
            const _SectionHeader('About'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About, privacy & contact'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.about),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _setTheme(PreferencesNotifier notifier, AppThemeMode? mode) {
    if (mode != null) notifier.setThemeMode(mode);
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
