import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/router/app_router.dart';
import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/empty_state.dart';
import '../reminders/reminders_providers.dart';

/// Month calendar showing notes with reminders. Days with reminders are marked;
/// selecting a day lists the notes due that day. Works fully offline.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesWithRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Calendar'),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load calendar: $e')),
        data: (notes) {
          final byDay = <DateTime, List<Note>>{};
          for (final note in notes) {
            final at = note.reminderAt;
            if (at == null) continue;
            final key = DateTime.utc(at.year, at.month, at.day);
            byDay.putIfAbsent(key, () => []).add(note);
          }
          List<Note> eventsFor(DateTime day) =>
              byDay[DateTime.utc(day.year, day.month, day.day)] ?? const [];

          final selected = eventsFor(_selectedDay);

          return Column(
            children: [
              TableCalendar<Note>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _format,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                eventLoader: eventsFor,
                onDaySelected: (selectedDay, focusedDay) => setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                }),
                onFormatChanged: (f) => setState(() => _format = f),
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selected.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Nothing scheduled',
                        message: 'No reminders on this day.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: selected.length,
                        itemBuilder: (context, i) {
                          final note = selected[i];
                          return ListTile(
                            leading: Icon(note.type == NoteType.checklist
                                ? Icons.checklist
                                : Icons.notes),
                            title: Text(
                              note.title.trim().isEmpty
                                  ? '(untitled)'
                                  : note.title,
                            ),
                            subtitle: note.reminderAt == null
                                ? null
                                : Text(formatNoteDate(note.reminderAt!)),
                            trailing:
                                const Icon(Icons.notifications_active, size: 18),
                            onTap: () => context.push(
                              note.type == NoteType.checklist
                                  ? Routes.checklist(note.id)
                                  : Routes.textNote(note.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
