import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/enums.dart';

/// Persisted app preferences loaded once at startup and kept in memory.
@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.layout = NoteLayout.grid,
    this.sort = NoteSort.modifiedDesc,
    this.defaultColorId = 0,
    this.autosave = true,
    this.onboardingDone = false,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.autoLockDelay = AutoLockDelay.immediately,
  });

  final AppThemeMode themeMode;
  final NoteLayout layout;
  final NoteSort sort;
  final int defaultColorId;
  final bool autosave;
  final bool onboardingDone;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final AutoLockDelay autoLockDelay;

  Duration get autoLockDuration => switch (autoLockDelay) {
        AutoLockDelay.immediately => Duration.zero,
        AutoLockDelay.oneMinute => const Duration(minutes: 1),
        AutoLockDelay.fiveMinutes => const Duration(minutes: 5),
        AutoLockDelay.tenMinutes => const Duration(minutes: 10),
      };

  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  AppPreferences copyWith({
    AppThemeMode? themeMode,
    NoteLayout? layout,
    NoteSort? sort,
    int? defaultColorId,
    bool? autosave,
    bool? onboardingDone,
    bool? appLockEnabled,
    bool? biometricEnabled,
    AutoLockDelay? autoLockDelay,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      layout: layout ?? this.layout,
      sort: sort ?? this.sort,
      defaultColorId: defaultColorId ?? this.defaultColorId,
      autosave: autosave ?? this.autosave,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockDelay: autoLockDelay ?? this.autoLockDelay,
    );
  }
}

/// Loads preferences from the database and persists changes back to it.
class PreferencesNotifier extends AsyncNotifier<AppPreferences> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<AppPreferences> build() async {
    final map = await _repo.loadAll();
    return AppPreferences(
      themeMode: _enum(map[SettingsRepository.kThemeMode], AppThemeMode.values,
          AppThemeMode.system),
      layout: _enum(
          map[SettingsRepository.kNoteLayout], NoteLayout.values, NoteLayout.grid),
      sort: _enum(map[SettingsRepository.kNoteSort], NoteSort.values,
          NoteSort.modifiedDesc),
      defaultColorId:
          int.tryParse(map[SettingsRepository.kDefaultColorId] ?? '') ?? 0,
      autosave: (map[SettingsRepository.kAutosave] ?? 'true') == 'true',
      onboardingDone:
          (map[SettingsRepository.kOnboardingDone] ?? 'false') == 'true',
      appLockEnabled:
          (map[SettingsRepository.kAppLockEnabled] ?? 'false') == 'true',
      biometricEnabled:
          (map[SettingsRepository.kBiometricEnabled] ?? 'false') == 'true',
      autoLockDelay: _enum(map[SettingsRepository.kAutoLockDelay],
          AutoLockDelay.values, AutoLockDelay.immediately),
    );
  }

  static T _enum<T extends Enum>(String? raw, List<T> values, T fallback) {
    final idx = int.tryParse(raw ?? '');
    if (idx != null && idx >= 0 && idx < values.length) return values[idx];
    return fallback;
  }

  Future<void> _update(
      AppPreferences next, String key, String value) async {
    state = AsyncData(next);
    await _repo.set(key, value);
  }

  Future<void> setThemeMode(AppThemeMode mode) => _update(
        _current.copyWith(themeMode: mode),
        SettingsRepository.kThemeMode,
        '${mode.index}',
      );

  Future<void> setLayout(NoteLayout layout) => _update(
        _current.copyWith(layout: layout),
        SettingsRepository.kNoteLayout,
        '${layout.index}',
      );

  Future<void> setSort(NoteSort sort) => _update(
        _current.copyWith(sort: sort),
        SettingsRepository.kNoteSort,
        '${sort.index}',
      );

  Future<void> setDefaultColorId(int id) => _update(
        _current.copyWith(defaultColorId: id),
        SettingsRepository.kDefaultColorId,
        '$id',
      );

  Future<void> setAutosave(bool value) => _update(
        _current.copyWith(autosave: value),
        SettingsRepository.kAutosave,
        '$value',
      );

  Future<void> completeOnboarding() => _update(
        _current.copyWith(onboardingDone: true),
        SettingsRepository.kOnboardingDone,
        'true',
      );

  Future<void> setAppLockEnabled(bool value) => _update(
        _current.copyWith(appLockEnabled: value),
        SettingsRepository.kAppLockEnabled,
        '$value',
      );

  Future<void> setBiometricEnabled(bool value) => _update(
        _current.copyWith(biometricEnabled: value),
        SettingsRepository.kBiometricEnabled,
        '$value',
      );

  Future<void> setAutoLockDelay(AutoLockDelay delay) => _update(
        _current.copyWith(autoLockDelay: delay),
        SettingsRepository.kAutoLockDelay,
        '${delay.index}',
      );

  AppPreferences get _current => state.value ?? const AppPreferences();
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, AppPreferences>(
  PreferencesNotifier.new,
);
