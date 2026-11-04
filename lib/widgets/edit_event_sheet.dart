import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/action_item.dart';

/// Lets the parent check and fix details before anything reaches their
/// calendar. Returns the edited item, or null if cancelled.
Future<ActionItem?> showEditEventSheet(BuildContext context, ActionItem item) {
  return showModalBottomSheet<ActionItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditEventSheet(item: item),
  );
}

class _EditEventSheet extends StatefulWidget {
  const _EditEventSheet({required this.item});
  final ActionItem item;

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late DateTime _when;
  late bool _allDay;
  late final bool _isDeadline;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _title = TextEditingController(text: i.title);
    _location = TextEditingController(text: i.location ?? '');
    _isDeadline = i.start == null && i.deadline != null;
    _when = i.start ?? i.deadline ?? DateTime.now();
    _allDay = _isDeadline || i.allDay;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _when = DateTime(
          picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_allDay ? DateTime(0, 1, 1, 9) : _when),
    );
    if (picked != null) {
      setState(() {
        _allDay = false;
        _when = DateTime(_when.year, _when.month, _when.day, picked.hour, picked.minute);
      });
    }
  }

  void _save() {
    final i = widget.item;
    final location = _location.text.trim();
    // Keep the original duration if the start moved.
    final duration = (i.start != null && i.end != null) ? i.end!.difference(i.start!) : null;
    final edited = _isDeadline
        ? i.copyWith(
            title: _title.text.trim().isEmpty ? i.title : _title.text.trim(),
            location: location,
            deadline: _when,
            allDay: true,
          )
        : i.copyWith(
            title: _title.text.trim().isEmpty ? i.title : _title.text.trim(),
            location: location,
            start: _when,
            end: duration != null ? _when.add(duration) : null,
            clearEnd: duration == null,
            allDay: _allDay,
          );
    Navigator.of(context).pop(edited);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isDeadline ? 'Add deadline to calendar' : 'Add to calendar',
              style: theme.textTheme.titleLarge),
          if (widget.item.needsCheck) ...[
            const SizedBox(height: 6),
            Text('Sortapp is not sure about these details. Please check them.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.tertiary)),
          ],
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(formatWhen(_when, allDay: true)),
                ),
              ),
              if (!_isDeadline) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(_allDay
                        ? 'All day'
                        : TimeOfDay.fromDateTime(_when).format(context)),
                  ),
                ),
              ],
            ],
          ),
          if (!_isDeadline && !_allDay)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _allDay = true),
                child: const Text('Make it all day'),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location (optional)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Add to Google Calendar'),
          ),
        ],
      ),
    );
  }
}
