import '../local/database.dart';

/// Typed access to the key/value [AppSettings] table.
///
/// Keys are centralised here so features never guess string keys.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  // Setting keys.
  static const kThemeMode = 'theme_mode';
  static const kNoteLayout = 'note_layout';
  static const kNoteSort = 'note_sort';
  static const kDefaultColorId = 'default_color_id';
  static const kAutosave = 'autosave';
  static const kOnboardingDone = 'onboarding_done';
  static const kNotifSound = 'notif_sound';
  static const kNotifVibration = 'notif_vibration';
  static const kAppLockEnabled = 'app_lock_enabled';
  static const kBiometricEnabled = 'biometric_enabled';
  static const kAutoLockDelay = 'auto_lock_delay';
  static const kPremium = 'premium_entitlement';

  /// Loads all settings into a plain map for a single startup read.
  Future<Map<String, String>> loadAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> remove(String key) async {
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
  }
}
