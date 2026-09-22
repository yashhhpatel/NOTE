import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Handles PIN storage/verification and biometric authentication for the app
/// lock. The PIN is never stored in plaintext: a random per-install salt plus
/// a SHA-256 hash are kept in Android Keystore-backed secure storage.
class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _kHash = 'lock_pin_hash';
  static const _kSalt = 'lock_pin_salt';

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _kHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Stores a salted hash of [pin]. Overwrites any existing PIN.
  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kSalt);
    final expected = await _storage.read(key: _kHash);
    if (salt == null || expected == null) return false;
    return _constantTimeEquals(_hash(pin, salt), expected);
  }

  /// Removes all PIN secrets (used when disabling lock or resetting).
  Future<void> clearPin() async {
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
  }

  /// Whether the device has enrolled biometrics available.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for biometric authentication. Returns true on success.
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Noteflow',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
