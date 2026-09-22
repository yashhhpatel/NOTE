import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'security_providers.dart';

/// Full-screen lock overlay with PIN entry and optional biometric unlock.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Offer biometrics automatically if enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometric());
  }

  Future<void> _maybeBiometric() async {
    final prefs = ref.read(preferencesProvider).valueOrNull;
    if (prefs == null || !prefs.biometricEnabled) return;
    final service = ref.read(appLockServiceProvider);
    if (await service.canUseBiometrics()) {
      final ok = await service.authenticateBiometric();
      if (ok && mounted) _unlock();
    }
  }

  void _unlock() => ref.read(lockedProvider.notifier).state = false;

  Future<void> _onDigit(String d) async {
    if (_busy || _entered.length >= 8) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length >= 4) {
      await _tryVerify();
    }
  }

  Future<void> _tryVerify() async {
    setState(() => _busy = true);
    final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      _unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Wrong PIN';
        _entered = '';
        _busy = false;
      });
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biometricEnabled =
        ref.watch(preferencesProvider).valueOrNull?.biometricEnabled ?? false;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Enter PIN',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _entered.isEmpty ? 4 : _entered.length.clamp(4, 8),
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entered.length
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: Text(_error ?? '',
                    style: TextStyle(color: scheme.error)),
              ),
              const SizedBox(height: 12),
              _Keypad(
                onDigit: _onDigit,
                onBackspace: _backspace,
                onBiometric: biometricEnabled ? _maybeBiometric : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: OutlinedButton(
            onPressed: onTap ?? () => onDigit(label),
            style: OutlinedButton.styleFrom(shape: const CircleBorder()),
            child: child ??
                Text(label,
                    style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            onBiometric == null
                ? const SizedBox(width: 88)
                : key('', onTap: onBiometric, child: const Icon(Icons.fingerprint)),
            key('0'),
            key('', onTap: onBackspace, child: const Icon(Icons.backspace_outlined)),
          ],
        ),
      ],
    );
  }
}
