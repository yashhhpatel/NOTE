import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(databaseProvider));
});

final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).watchAll();
});

/// Live count of active notes in each category.
final categoryCountsProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(categoriesRepositoryProvider).watchCounts();
});
