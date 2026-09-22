import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';

/// Persistence for categories/folders.
class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<List<Category>> getAll() => (_db.select(_db.categories)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<Category> create(String name, {int? colorId}) async {
    final companion = CategoriesCompanion.insert(
      id: _uuid.v4(),
      name: name.trim(),
      colorId: Value(colorId),
      createdAt: DateTime.now(),
    );
    return _db.into(_db.categories).insertReturning(companion);
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
        .write(CategoriesCompanion(name: Value(name.trim())));
  }

  /// Deletes a category. Notes in it are NOT deleted — they are made
  /// uncategorised (categoryId set to null) in the same transaction.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.categoryId.equals(id)))
          .write(const NotesCompanion(categoryId: Value(null)));
      await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Live count of active notes per category id.
  Stream<Map<String, int>> watchCounts() {
    final notes = _db.notes;
    final count = notes.id.count();
    final query = _db.selectOnly(notes)
      ..where(notes.archived.equals(false) &
          notes.trashed.equals(false) &
          notes.categoryId.isNotNull())
      ..addColumns([notes.categoryId, count])
      ..groupBy([notes.categoryId]);
    return query.watch().map((rows) {
      return {
        for (final row in rows)
          row.read(notes.categoryId)!: row.read(count) ?? 0,
      };
    });
  }
}
