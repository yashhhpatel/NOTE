import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../categories/categories_providers.dart';
import '../../notes/notes_providers.dart';

/// The main navigation drawer: filters (all / uncategorised / categories) and
/// links to management screens.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(homeFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final counts = ref.watch(categoryCountsProvider).valueOrNull ?? const {};
    final scheme = Theme.of(context).colorScheme;

    void select(HomeFilter f) {
      ref.read(homeFilterProvider.notifier).state = f;
      Navigator.pop(context);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: scheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Text('Noteflow',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            _DrawerTile(
              icon: Icons.notes,
              label: 'All notes',
              selected: filter == const HomeFilter.all(),
              onTap: () => select(const HomeFilter.all()),
            ),
            _DrawerTile(
              icon: Icons.label_off_outlined,
              label: 'Uncategorised',
              selected: filter == const HomeFilter.uncategorized(),
              onTap: () => select(const HomeFilter.uncategorized()),
            ),
            const Divider(),
            if (categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('CATEGORIES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
              ),
            for (final c in categories)
              _DrawerTile(
                icon: Icons.folder_outlined,
                label: c.name,
                trailing: '${counts[c.id] ?? 0}',
                selected: filter == HomeFilter.category(c.id),
                onTap: () => select(HomeFilter.category(c.id)),
              ),
            _DrawerTile(
              icon: Icons.create_new_folder_outlined,
              label: 'Manage categories',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.categories);
              },
            ),
            const Divider(),
            _DrawerTile(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.archive);
              },
            ),
            _DrawerTile(
              icon: Icons.delete_outline,
              label: 'Trash',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.trash);
              },
            ),
            const Divider(),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.settings);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? scheme.primary : null),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.primary : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      trailing: trailing == null ? null : Text(trailing!),
      selected: selected,
      selectedTileColor: scheme.primary.withOpacity(0.08),
      onTap: onTap,
    );
  }
}
