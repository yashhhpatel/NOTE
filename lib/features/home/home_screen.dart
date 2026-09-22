import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../shared/widgets/empty_state.dart';

/// Phase 1 home shell.
///
/// The top bar exposes search / sort / menu affordances and the FAB exposes
/// note creation. These become fully functional in Phase 2 once the notes
/// repository and editor land; for now they establish the navigation surface.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noteflow'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: const EmptyState(
        icon: Icons.note_alt_outlined,
        title: 'No notes yet',
        message: 'Create your first note to get started.',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
