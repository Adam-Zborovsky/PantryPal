import 'package:flutter/material.dart';

import 'scheduling.dart';

/// Read-only field that opens native date and time pickers instead of asking
/// for a raw ISO 8601 string. Reports UTC ISO 8601 through [onChanged]; an
/// empty string means "cleared" for optional fields.
class ScheduledDateTimeField extends StatelessWidget {
  const ScheduledDateTimeField({
    super.key,
    required this.label,
    required this.valueIso,
    required this.onChanged,
    this.helperText,
    this.initialTime = const TimeOfDay(hour: 18, minute: 0),
  });

  final String label;
  final String? valueIso;
  final ValueChanged<String> onChanged;
  final String? helperText;

  /// Default time offered when only a date is chosen.
  final TimeOfDay initialTime;

  @override
  Widget build(BuildContext context) {
    final current = tryParseScheduled(valueIso);
    return TextField(
      readOnly: true,
      controller: TextEditingController(
        text: current == null ? '' : formatScheduledForDisplay(current),
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: current == null
            ? const Icon(Icons.event_outlined)
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(''),
              ),
      ),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final current = tryParseScheduled(valueIso);
    final initialDate = current ?? DateTime.now();
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 2);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isBefore(firstDate) || initialDate.isAfter(lastDate)
          ? now
          : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    final time = pickedTime ?? initialTime;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
    );
    onChanged(scheduledToApi(combined));
  }
}
