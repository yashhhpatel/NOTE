import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Whether the app is currently locked (showing the lock screen).
final lockedProvider = StateProvider<bool>((ref) => false);
