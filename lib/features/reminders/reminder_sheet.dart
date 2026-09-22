import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../shared/utils/snackbars.dart';
import 'reminders_providers.dart';

/// Opens the reminder editor for a note. Lets the user pick a date, time and
/// repeat rule, or remove an existing reminder.
Future<void> showReminderSheet(
  BuildContext context,
  WidgetRef ref, {
  required String noteId,
  required String noteTitle,
  required String notePreview,
}) async {
  final existing =
      await ref.read(remindersRepositoryProvider).getForNote(noteId);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReminderSheet(
      noteId: noteId,
      noteTitle: noteTitle,
      notePreview: notePreview,
      existing: existing,
    ),
  );
}

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({
    required this.noteId,
    required this.noteTitle,
    required this.notePreview,
    required this.existing,
  });

  final String noteId;
  final String noteTitle;
  final String notePreview;
  final Reminder? existing;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  late ReminderRepeat _repeat;
  int _customDays = 2;

  @override
  void initState() {
    super.initState();
    final base = widget.existing?.triggerAt ??
        DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    _repeat = widget.existing?.repeat ?? ReminderRepeat.none;
    _customDays = widget.existing?.customIntervalDays ?? 2;
  }

  DateTime get _triggerAt => DateTime(
      _date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminder', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat.yMMMEd().format(_date)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_time.format(context)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Repeat', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in ReminderRepeat.values)
                ChoiceChip(
                  label: Text(_repeatLabel(r)),
                  selected: _repeat == r,
                  onSelected: (_) => setState(() => _repeat = r),
                ),
            ],
          ),
          if (_repeat == ReminderRepeat.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Every'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _customDays > 1
                      ? () => setState(() => _customDays--)
                      : null,
                ),
                Text('$_customDays'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _customDays++),
                ),
                const Text('days'),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('Remove'),
                  onPressed: _remove,
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final service = ref.read(reminderServiceProvider);
    final granted = await service.requestPermissions();
    if (!granted && mounted) {
      showInfoSnackBar(context,
          'Enable notifications in system settings to receive reminders.');
    }
    final reminder = await ref.read(remindersRepositoryProvider).upsert(
          noteId: widget.noteId,
          triggerAt: _triggerAt,
          repeat: _repeat,
          customIntervalDays:
              _repeat == ReminderRepeat.custom ? _customDays : null,
        );
    await service.schedule(reminder,
        noteTitle: widget.noteTitle, notePreview: widget.notePreview);
    if (mounted) {
      Navigator.pop(context);
      showInfoSnackBar(context, 'Reminder set');
    }
  }

  Future<void> _remove() async {
    final existing = widget.existing;
    if (existing != null) {
      await ref.read(reminderServiceProvider).cancel(existing.notificationId);
      await ref
          .read(remindersRepositoryProvider)
          .cancelForNote(widget.noteId);
    }
    if (mounted) {
      Navigator.pop(context);
      showInfoSnackBar(context, 'Reminder removed');
    }
  }

  String _repeatLabel(ReminderRepeat r) => switch (r) {
        ReminderRepeat.none => 'Once',
        ReminderRepeat.daily => 'Daily',
        ReminderRepeat.weekly => 'Weekly',
        ReminderRepeat.monthly => 'Monthly',
        ReminderRepeat.custom => 'Custom',
      };
}
