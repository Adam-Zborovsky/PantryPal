import 'package:flutter/material.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import 'scheduling.dart';
import 'status_tone.dart' show humanStatusLabel;

/// True when [tripDate] falls on a later calendar day than [mealDate].
/// A trip on the same day, or a missing trip/meal date, is never "after"
/// the meal — comparison is by calendar date, not time of day.
bool tripIsAfterMeal(DateTime? tripDate, DateTime? mealDate) {
  if (tripDate == null || mealDate == null) return false;
  final trip = DateTime(tripDate.year, tripDate.month, tripDate.day);
  final meal = DateTime(mealDate.year, mealDate.month, mealDate.day);
  return trip.isAfter(meal);
}

/// Radio list of open shopping trips for assigning a meal. Reused by the
/// Plan meal-detail "Change trip" sheet and the recipe "Add to shopping
/// trip" sheet.
class TripPicker extends StatelessWidget {
  const TripPicker({
    super.key,
    required this.trips,
    required this.selectedTripId,
    required this.mealDate,
    required this.onChanged,
    this.allowNone = false,
  });

  /// Open trips (PROPOSED/CONFIRMED/IN_PROGRESS) to offer as options.
  final List<HouseholdCollectionItem> trips;
  final String? selectedTripId;

  /// The meal's cooking date, used to flag trips scheduled after it.
  final DateTime? mealDate;
  final ValueChanged<String?> onChanged;

  /// Whether to offer a "No shopping trip" option representing `null`.
  final bool allowNone;

  /// Radio value standing in for `null`; trip ids are never empty.
  static const _noTrip = '';

  @override
  Widget build(BuildContext context) {
    final options = <Widget>[
      if (allowNone)
        const _TripOption(
          value: _noTrip,
          label: 'No shopping trip',
          status: null,
          afterMeal: false,
        ),
      for (final trip in trips)
        if (trip.string('id') case final id? when id.isNotEmpty)
          _TripOption(
            value: id,
            label: tripPickerLabel(trip),
            status: trip.string('status'),
            afterMeal: tripIsAfterMeal(
              tryParseScheduled(trip.string('scheduledFor')),
              mealDate,
            ),
          ),
    ];
    return RadioGroup<String>(
      groupValue: selectedTripId ?? (allowNone ? _noTrip : null),
      onChanged: (value) {
        if (value == null) return;
        onChanged(value == _noTrip ? null : value);
      },
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            options[i],
            if (i != options.length - 1)
              const Divider(height: 1, color: PantryPalTheme.line),
          ],
        ],
      ),
    );
  }
}

/// The display label for a trip option: its formatted scheduled date, or
/// "Unscheduled trip" when it has none.
String tripPickerLabel(HouseholdCollectionItem trip) {
  final scheduled = tryParseScheduled(trip.string('scheduledFor'));
  return scheduled == null
      ? 'Unscheduled trip'
      : formatScheduledForDisplay(scheduled);
}

class _TripOption extends StatelessWidget {
  const _TripOption({
    required this.value,
    required this.label,
    required this.status,
    required this.afterMeal,
  });

  final String value;
  final String label;
  final String? status;
  final bool afterMeal;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final status = this.status;
    final ready = status == 'CONFIRMED' || status == 'IN_PROGRESS';
    return RadioListTile<String>(
      value: value,
      contentPadding: EdgeInsets.zero,
      // Unselected rings use the text colour so they stay visible (3:1+).
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? PantryPalTheme.tomato : ink,
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: afterMeal
          ? const Text(
              'After this meal',
              style: TextStyle(
                color: PantryPalTheme.amber,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )
          : null,
      secondary: status == null
          ? null
          : Text(
              humanStatusLabel(status),
              style: TextStyle(
                color: ready ? PantryPalTheme.green : ink,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
