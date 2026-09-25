import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// Keeps the Android home-screen widget's data in sync. The widget itself is
/// a native `AppWidgetProvider` (see android/.../NoteflowWidgetProvider.kt)
/// that reads these keys and re-renders on `HomeWidget.updateWidget`.
///
/// Sync happens whenever the app is open and the active-notes list changes;
/// there is no background isolate, so the widget reflects the last state the
/// app observed rather than updating while fully closed — a deliberate,
/// simple trade-off.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const _androidProviderName = 'NoteflowWidgetProvider';
  static const kActiveCount = 'active_count';
  static const kPinnedTitles = 'pinned_titles';

  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId('group.com.noteflow.app');
    } catch (_) {
      // App group id is iOS-only; harmless if it fails on Android.
    }
  }

  /// Updates the widget's data and asks Android to redraw it.
  Future<void> sync({
    required int activeCount,
    required List<String> pinnedTitles,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>(kActiveCount, activeCount);
      await HomeWidget.saveWidgetData<String>(
        kPinnedTitles,
        jsonEncode(pinnedTitles.take(3).toList()),
      );
      await HomeWidget.updateWidget(androidName: _androidProviderName);
    } catch (_) {
      // The widget is a nice-to-have; never let a sync failure affect notes.
    }
  }
}
