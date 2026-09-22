import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/core/services/app_lock_service.dart';

/// In-memory stand-in for platform secure storage so PIN logic is testable
/// without a device/Keystore.
class _FakeSecureStorage extends FlutterSecureStorage {
  const _FakeSecureStorage(this._store);
  final Map<String, String> _store;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  late Map<String, String> store;
  late AppLockService service;

  setUp(() {
    store = {};
    service = AppLockService(storage: _FakeSecureStorage(store));
  });

  group('AppLockService', () {
    test('no PIN initially', () async {
      expect(await service.hasPin(), isFalse);
      expect(await service.verifyPin('1234'), isFalse);
    });

    test('setPin then verifyPin succeeds for the correct PIN', () async {
      await service.setPin('1234');
      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('1234'), isTrue);
      expect(await service.verifyPin('0000'), isFalse);
    });

    test('PIN is never stored in plaintext', () async {
      await service.setPin('5678');
      expect(store.values, isNot(contains('5678')));
      // A salt and a hash are stored.
      expect(store.length, 2);
    });

    test('each setPin uses a fresh salt (different hash for same PIN)',
        () async {
      await service.setPin('1234');
      final firstHash = store['lock_pin_hash'];
      await service.setPin('1234');
      final secondHash = store['lock_pin_hash'];
      expect(firstHash, isNotNull);
      expect(firstHash, isNot(secondHash));
      expect(await service.verifyPin('1234'), isTrue);
    });

    test('clearPin removes the PIN', () async {
      await service.setPin('1234');
      await service.clearPin();
      expect(await service.hasPin(), isFalse);
      expect(await service.verifyPin('1234'), isFalse);
    });
  });
}
