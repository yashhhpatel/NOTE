import 'package:flutter/material.dart';

import 'entities/enums.dart';

/// A built-in starter for the "New from template" flow. Purely data — creating
/// the actual note/items happens in NotesRepository.createFromTemplate.
class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.title = '',
    this.content = '',
    this.items = const [],
  });

  final String id;
  final String name;
  final IconData icon;
  final NoteType type;

  /// Pre-filled title.
  final String title;

  /// Pre-filled body (text notes only).
  final String content;

  /// Pre-filled checklist item labels (checklist notes only).
  final List<String> items;
}

/// Noteflow's built-in templates. Purely local — no data ever leaves the
/// device, and templates are just presets for content the user then owns.
class NoteTemplates {
  const NoteTemplates._();

  static const List<NoteTemplate> all = [
    NoteTemplate(
      id: 'shopping_list',
      name: 'Shopping list',
      icon: Icons.shopping_cart_outlined,
      type: NoteType.checklist,
      title: 'Shopping list',
      items: ['Milk', 'Eggs', 'Bread', 'Fruit'],
    ),
    NoteTemplate(
      id: 'packing_list',
      name: 'Packing list',
      icon: Icons.luggage_outlined,
      type: NoteType.checklist,
      title: 'Packing list',
      items: ['Phone charger', 'Toothbrush', 'Passport / ID', 'Medication'],
    ),
    NoteTemplate(
      id: 'todo_list',
      name: 'To-do list',
      icon: Icons.checklist_outlined,
      type: NoteType.checklist,
      title: 'To-do',
      items: ['Task 1', 'Task 2', 'Task 3'],
    ),
    NoteTemplate(
      id: 'meeting_notes',
      name: 'Meeting notes',
      icon: Icons.groups_outlined,
      type: NoteType.text,
      title: 'Meeting notes',
      content: 'Attendees:\n\nAgenda:\n\nDecisions:\n\nAction items:\n',
    ),
    NoteTemplate(
      id: 'daily_journal',
      name: 'Daily journal',
      icon: Icons.book_outlined,
      type: NoteType.text,
      title: 'Journal',
      content: 'Today I...\n\nGrateful for...\n\nTomorrow I will...\n',
    ),
  ];
}
