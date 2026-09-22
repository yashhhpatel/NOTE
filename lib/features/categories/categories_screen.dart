import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/database.dart';
import '../../shared/utils/snackbars.dart';
import '../../shared/widgets/empty_state.dart';
import 'categories_providers.dart';

/// Manage categories/folders: create, rename, delete.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final counts = ref.watch(categoryCountsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Categories'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load categories: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_outlined,
              title: 'No categories yet',
              message: 'Create a category to organise your notes.',
            );
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final c = categories[i];
              final count = counts[c.id] ?? 0;
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                subtitle: Text('$count ${count == 1 ? 'note' : 'notes'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _onAction(context, ref, v, c),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New category'),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Category category,
  ) async {
    switch (action) {
      case 'rename':
        await _showEditDialog(context, ref, existing: category);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete category?'),
            content: Text(
              'Notes in "${category.name}" will be kept and moved to '
              'Uncategorised. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(categoriesRepositoryProvider).delete(category.id);
          if (context.mounted) {
            showInfoSnackBar(context, 'Category deleted');
          }
        }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New category' : 'Rename category'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final repo = ref.read(categoriesRepositoryProvider);
    if (existing == null) {
      await repo.create(name);
    } else {
      await repo.rename(existing.id, name);
    }
  }
}
