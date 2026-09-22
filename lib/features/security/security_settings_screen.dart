import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/enums.dart';
import '../../shared/utils/snackbars.dart';
import '../notes/notes_providers.dart';
import '../reminders/reminders_providers.dart';
import '../settings/settings_providers.dart';
import 'pin_setup_dialog.dart';
import 'security_providers.dart';

/// Security settings: app lock (PIN), biometric unlock and auto-lock delay.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Security'),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (prefs) => ListView(
          children: [
            SwitchListTile(
              title: const Text('App lock'),
              subtitle: const Text('Require a PIN to open the app'),
              value: prefs.appLockEnabled,
              onChanged: (v) => _toggleAppLock(context, ref, v),
            ),
            if (prefs.appLockEnabled) ...[
              SwitchListTile(
                title: const Text('Biometric unlock'),
                subtitle: const Text('Use fingerprint or face if available'),
                value: prefs.biometricEnabled,
                onChanged: (v) => _toggleBiometric(context, ref, v),
              ),
              ListTile(
                title: const Text('Change PIN'),
                leading: const Icon(Icons.pin_outlined),
                onTap: () => _changePin(context, ref),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Auto-lock'),
              ),
              for (final delay in AutoLockDelay.values)
                RadioListTile<AutoLockDelay>(
                  value: delay,
                  groupValue: prefs.autoLockDelay,
                  title: Text(_delayLabel(delay)),
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(preferencesProvider.notifier)
                          .setAutoLockDelay(v);
                    }
                  },
                ),
              const Divider(),
              ListTile(
                title: const Text('Forgot PIN'),
                subtitle:
                    const Text('Reset access by erasing all local notes'),
                leading: const Icon(Icons.lock_reset),
                onTap: () => _forgotPin(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAppLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    final service = ref.read(appLockServiceProvider);
    final prefsNotifier = ref.read(preferencesProvider.notifier);
    if (enable) {
      final pin = await showPinSetupDialog(context);
      if (pin == null) return;
      await service.setPin(pin);
      await prefsNotifier.setAppLockEnabled(true);
      if (context.mounted) showInfoSnackBar(context, 'App lock enabled');
    } else {
      await service.clearPin();
      await prefsNotifier.setAppLockEnabled(false);
      await prefsNotifier.setBiometricEnabled(false);
      if (context.mounted) showInfoSnackBar(context, 'App lock disabled');
    }
  }

  Future<void> _toggleBiometric(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (!enable) {
      await ref.read(preferencesProvider.notifier).setBiometricEnabled(false);
      return;
    }
    final service = ref.read(appLockServiceProvider);
    if (!await service.canUseBiometrics()) {
      if (context.mounted) {
        showInfoSnackBar(context, 'No biometrics enrolled on this device.');
      }
      return;
    }
    final ok = await service.authenticateBiometric();
    if (ok) {
      await ref.read(preferencesProvider.notifier).setBiometricEnabled(true);
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final pin = await showPinSetupDialog(context);
    if (pin == null) return;
    await ref.read(appLockServiceProvider).setPin(pin);
    if (context.mounted) showInfoSnackBar(context, 'PIN changed');
  }

  Future<void> _forgotPin(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset access?'),
        content: const Text(
          'For your security there is no way to recover a forgotten PIN. '
          'The only way to regain access is to erase all local notes and '
          'disable the lock.\n\nThis permanently deletes every note on this '
          'device and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase & reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Cancel any scheduled reminders, wipe content, clear secrets.
    final active = await ref.read(remindersRepositoryProvider).getActive();
    for (final r in active) {
      await ref.read(reminderServiceProvider).cancel(r.notificationId);
    }
    await ref.read(notesRepositoryProvider).deleteAllNoteData();
    await ref.read(appLockServiceProvider).clearPin();
    await ref.read(preferencesProvider.notifier).setAppLockEnabled(false);
    await ref.read(preferencesProvider.notifier).setBiometricEnabled(false);
    ref.read(lockedProvider.notifier).state = false;
    if (context.mounted) {
      showInfoSnackBar(context, 'Access reset and notes erased');
    }
  }

  String _delayLabel(AutoLockDelay d) => switch (d) {
        AutoLockDelay.immediately => 'Immediately',
        AutoLockDelay.oneMinute => 'After 1 minute',
        AutoLockDelay.fiveMinutes => 'After 5 minutes',
        AutoLockDelay.tenMinutes => 'After 10 minutes',
      };
}
