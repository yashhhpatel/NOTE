import 'package:flutter/material.dart';

import '../../domain/note_templates.dart';

/// Shows a sheet listing built-in templates. Returns the chosen template, or
/// null if dismissed.
Future<NoteTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<NoteTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Start from a template',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in NoteTemplates.all)
                  ListTile(
                    leading: Icon(t.icon),
                    title: Text(t.name),
                    onTap: () => Navigator.pop(context, t),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
