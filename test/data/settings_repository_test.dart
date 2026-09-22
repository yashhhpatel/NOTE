import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/data/repositories/settings_repository.dart';

import '../util/test_db.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsRepository', skip: sqlite3Available ? false : sqlite3MissingReason, () {
    test('returns null for a missing key', () async {
      expect(await repo.get('does_not_exist'), isNull);
    });

    test('persists and reads back a value', () async {
      await repo.set(SettingsRepository.kThemeMode, '2');
      expect(await repo.get(SettingsRepository.kThemeMode), '2');
    });

    test('set overwrites an existing value (upsert)', () async {
      await repo.set(SettingsRepository.kNoteSort, '0');
      await repo.set(SettingsRepository.kNoteSort, '3');
      expect(await repo.get(SettingsRepository.kNoteSort), '3');
    });

    test('loadAll returns every stored setting', () async {
      await repo.set(SettingsRepository.kThemeMode, '1');
      await repo.set(SettingsRepository.kAutosave, 'false');
      final all = await repo.loadAll();
      expect(all[SettingsRepository.kThemeMode], '1');
      expect(all[SettingsRepository.kAutosave], 'false');
    });

    test('remove deletes a value', () async {
      await repo.set(SettingsRepository.kPremium, 'true');
      await repo.remove(SettingsRepository.kPremium);
      expect(await repo.get(SettingsRepository.kPremium), isNull);
    });
  });
}
