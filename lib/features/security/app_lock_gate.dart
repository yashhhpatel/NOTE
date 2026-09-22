import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'lock_screen.dart';
import 'security_providers.dart';

/// Wraps the app, showing the lock screen when the app is locked. Handles
/// lifecycle-aware auto-lock: the app re-locks on resume once the configured
/// delay has elapsed since it was backgrounded. Active editing is never
/// interrupted because locking only happens on resume, not during use.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _lockIfEnabledAtStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockIfEnabledAtStart() async {
    if (_initialised) return;
    _initialised = true;
    final prefs = await ref.read(preferencesProvider.future);
    if (prefs.appLockEnabled &&
        await ref.read(appLockServiceProvider).hasPin()) {
      ref.read(lockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        _maybeLockOnResume();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _maybeLockOnResume() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;

    final prefs = ref.read(preferencesProvider).valueOrNull;
    if (prefs == null || !prefs.appLockEnabled) return;
    if (ref.read(lockedProvider)) return; // already locked

    final elapsed = DateTime.now().difference(backgroundedAt);
    if (elapsed >= prefs.autoLockDuration &&
        await ref.read(appLockServiceProvider).hasPin()) {
      ref.read(lockedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(lockedProvider);
    return Stack(
      children: [
        widget.child,
        if (locked)
          const Positioned.fill(
            child: Material(child: LockScreen()),
          ),
      ],
    );
  }
}
