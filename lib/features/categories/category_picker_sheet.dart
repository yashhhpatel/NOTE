import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'categories_providers.dart';

/// Result of the category picker.
class CategoryChoice {
  const CategoryChoice(this.categoryId);

  /// null means "Uncategorised".
  final String? categoryId;
}

/// Shows a sheet to move a note (or notes) into a category, with an option to
/// create a new one inline. Returns null if dismissed.
Future<CategoryChoice?> showCategoryPicker(BuildContext context) {
  return showModalBottomSheet<CategoryChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _CategoryPickerSheet(),
  );
}

class _CategoryPickerSheet extends ConsumerWidget {
  const _CategoryPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Move to category',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.label_off_outlined),
                  title: const Text('Uncategorised'),
                  onTap: () =>
                      Navigator.pop(context, const CategoryChoice(null)),
                ),
                for (final c in categories)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(c.name),
                    onTap: () => Navigator.pop(context, CategoryChoice(c.id)),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New category…'),
                  onTap: () async {
                    final id = await _createCategory(context, ref);
                    if (id != null && context.mounted) {
                      Navigator.pop(context, CategoryChoice(id));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _createCategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Category name'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    final category =
        await ref.read(categoriesRepositoryProvider).create(name);
    return category.id;
  }
}
