import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repositories/backup_repository.dart';
import '../../shared/utils/snackbars.dart';
import 'backup_providers.dart';

/// Backup & restore screen: export to JSON/TXT (shared as files) and import
/// from a JSON backup with validation and merge/replace choice. No backend.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Backup & restore'),
      ),
      body: ListView(
        children: [
          const _Header('Export'),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Export backup (JSON)'),
            subtitle: const Text('Full backup you can restore later'),
            onTap: () => _exportJson(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Export as text (TXT)'),
            subtitle: const Text('Readable copy of your notes'),
            onTap: () => _exportText(context, ref),
          ),
          const Divider(),
          const _Header('Restore'),
          ListTile(
            leading: const Icon(Icons.restore_page_outlined),
            title: const Text('Import backup (JSON)'),
            subtitle: const Text('Merge or replace from a backup file'),
            onTap: () => _import(context, ref),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Backups are plain files stored only where you choose. Your notes '
              'are never uploaded anywhere.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(backupRepositoryProvider).exportJson();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = await _writeTemp('noteflow_backup_$stamp.json', json);
      await Share.shareXFiles([XFile(path)], subject: 'Noteflow backup');
    } catch (e) {
      if (context.mounted) showInfoSnackBar(context, 'Export failed: $e');
    }
  }

  Future<void> _exportText(BuildContext context, WidgetRef ref) async {
    try {
      final text = await ref.read(backupRepositoryProvider).exportText();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = await _writeTemp('noteflow_notes_$stamp.txt', text);
      await Share.shareXFiles([XFile(path)], subject: 'Noteflow notes');
    } catch (e) {
      if (context.mounted) showInfoSnackBar(context, 'Export failed: $e');
    }
  }

  Future<String> _writeTemp(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(contents);
    return file.path;
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    const typeGroup = XTypeGroup(label: 'backup', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final repo = ref.read(backupRepositoryProvider);
    String contents;
    try {
      contents = await file.readAsString();
      repo.validate(contents); // throws on malformed
    } on BackupException catch (e) {
      if (context.mounted) showInfoSnackBar(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) showInfoSnackBar(context, 'Could not read file.');
      return;
    }

    if (!context.mounted) return;
    final mode = await showDialog<_ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup'),
        content: const Text(
          'Merge keeps your current notes and adds any missing ones. '
          'Replace deletes all current notes first.\n\nDuplicates are never '
          'created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ImportMode.merge),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ImportMode.replace),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (mode == null) return;

    try {
      final count =
          await repo.import(contents, replace: mode == _ImportMode.replace);
      if (context.mounted) {
        showInfoSnackBar(context, 'Restored $count notes');
      }
    } catch (e) {
      if (context.mounted) showInfoSnackBar(context, 'Restore failed: $e');
    }
  }
}

enum _ImportMode { merge, replace }

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
