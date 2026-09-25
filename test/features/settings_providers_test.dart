import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow/core/providers.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:noteflow/domain/entities/enums.dart';
import 'package:noteflow/features/settings/settings_providers.dart';

import '../util/test_db.dart';

void main() {
  group('PreferencesNotifier',
      skip: sqlite3Available ? false : sqlite3MissingReason, () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = openTestDatabase();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('defaults onboardingDone to false before completion', () async {
      final prefs = await container.read(preferencesProvider.future);
      expect(prefs.onboardingDone, isFalse);
    });

    test('completeOnboarding persists and updates state', () async {
      await container.read(preferencesProvider.future); // ensure loaded
      await container.read(preferencesProvider.notifier).completeOnboarding();

      final updated = container.read(preferencesProvider).requireValue;
      expect(updated.onboardingDone, isTrue);
    });

    test('onboardingDone survives a fresh notifier reading the same db',
        () async {
      await container.read(preferencesProvider.future);
      await container.read(preferencesProvider.notifier).completeOnboarding();

      // Simulate a fresh app start against the same underlying database.
      final container2 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      final prefs2 = await container2.read(preferencesProvider.future);
      expect(prefs2.onboardingDone, isTrue);
    });

    test('setLayout persists and is readable back', () async {
      await container.read(preferencesProvider.future);
      await container.read(preferencesProvider.notifier).setLayout(NoteLayout.list);
      final updated = container.read(preferencesProvider).requireValue;
      expect(updated.layout, NoteLayout.list);
    });
  });
}
