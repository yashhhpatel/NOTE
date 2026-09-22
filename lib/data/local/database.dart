import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/enums.dart';
import 'tables.dart';

part 'database.g.dart';

/// The single Drift database for Noteflow.
///
/// All persistence flows through this class. Repositories wrap it to expose
/// domain-friendly APIs; widgets never touch it directly.
@DriftDatabase(
  tables: [
    Notes,
    ChecklistItems,
    Categories,
    Reminders,
    Attachments,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test/injection constructor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        beforeOpen: (details) async {
          // Enforce foreign keys and reasonable durability.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Indexes that keep list/search/calendar queries fast at scale.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_state '
      'ON notes (archived, trashed, pinned, modified_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_category ON notes (category_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_items_note ON checklist_items (note_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reminders_note ON reminders (note_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attachments_note '
      'ON attachments (note_id)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'noteflow.sqlite'));

    // Work around old Android sqlite versions bundling / temp dir issues.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
