import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/shared/scheduling.dart';
import 'package:pantry_pal/features/shared/trip_picker.dart';

HouseholdCollectionItem _trip({
  required String id,
  String? scheduledFor,
  String status = 'PROPOSED',
}) => HouseholdCollectionItem({
  'id': id,
  'scheduledFor': scheduledFor,
  'status': status,
});

/// The API's wire format: a Z-suffixed UTC timestamp for a local moment.
String _utcIso(DateTime local) => local.toUtc().toIso8601String();

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final light = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required List<HouseholdCollectionItem> trips,
  required String? selectedTripId,
  DateTime? mealDate,
  bool allowNone = false,
  ValueChanged<String?>? onChanged,
}) => tester.pumpWidget(
  MaterialApp(
    theme: PantryPalTheme.light(),
    home: Scaffold(
      body: TripPicker(
        trips: trips,
        selectedTripId: selectedTripId,
        mealDate: mealDate,
        allowNone: allowNone,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  ),
);

void main() {
  group('tripIsAfterMeal', () {
    test('a trip on the same calendar day is not after the meal', () {
      expect(
        tripIsAfterMeal(DateTime(2026, 9, 20, 8), DateTime(2026, 9, 20, 18)),
        isFalse,
      );
    });

    test('a trip on a later calendar day is after the meal', () {
      expect(
        tripIsAfterMeal(DateTime(2026, 9, 21), DateTime(2026, 9, 20)),
        isTrue,
      );
    });

    test('compares local calendar days of UTC API timestamps', () {
      DateTime? parse(DateTime local) => tryParseScheduled(_utcIso(local));
      expect(
        tripIsAfterMeal(
          parse(DateTime(2026, 9, 21, 0, 30)),
          parse(DateTime(2026, 9, 20, 23, 30)),
        ),
        isTrue,
      );
      expect(
        tripIsAfterMeal(
          parse(DateTime(2026, 9, 20, 0, 30)),
          parse(DateTime(2026, 9, 20, 23, 30)),
        ),
        isFalse,
      );
    });

    test('a missing trip or meal date is never after the meal', () {
      expect(tripIsAfterMeal(null, DateTime(2026, 9, 20)), isFalse);
      expect(tripIsAfterMeal(DateTime(2026, 9, 20), null), isFalse);
      expect(tripIsAfterMeal(null, null), isFalse);
    });
  });

  group('TripPicker', () {
    testWidgets(
      'flags only the trip scheduled after the meal, and reports the tapped selection',
      (tester) async {
        final mealDate = DateTime(2026, 9, 20, 18);
        final beforeTrip = DateTime(2026, 9, 18, 10);
        final afterTrip = DateTime(2026, 9, 22, 10);
        String? changedTo;

        await _pumpPicker(
          tester,
          trips: [
            _trip(
              id: 'before',
              scheduledFor: _utcIso(beforeTrip),
              status: 'CONFIRMED',
            ),
            _trip(id: 'after', scheduledFor: _utcIso(afterTrip)),
          ],
          selectedTripId: 'before',
          mealDate: mealDate,
          onChanged: (value) => changedTo = value,
        );

        expect(find.text('After this meal'), findsOneWidget);

        await tester.tap(find.text(formatScheduledForDisplay(afterTrip)));
        expect(changedTo, 'after');
      },
    );

    testWidgets('labels UTC trip dates in local time', (tester) async {
      final local = DateTime(2026, 9, 19, 0, 30);
      await _pumpPicker(
        tester,
        trips: [_trip(id: 'trip-1', scheduledFor: _utcIso(local))],
        selectedTripId: null,
      );

      expect(find.text(formatScheduledForDisplay(local)), findsOneWidget);
    });

    testWidgets('offers "No shopping trip" and reports it when allowNone', (
      tester,
    ) async {
      String? changedTo = 'unset';
      await _pumpPicker(
        tester,
        trips: const [],
        selectedTripId: 'trip-1',
        allowNone: true,
        onChanged: (value) => changedTo = value,
      );

      expect(find.text('No shopping trip'), findsOneWidget);
      await tester.tap(find.text('No shopping trip'));
      expect(changedTo, isNull);
    });

    testWidgets('shows an unscheduled trip with a plain label', (tester) async {
      await _pumpPicker(
        tester,
        trips: [_trip(id: 'unscheduled')],
        selectedTripId: null,
        mealDate: DateTime(2026, 9, 20),
      );

      expect(find.text('Unscheduled trip'), findsOneWidget);
      expect(find.text('After this meal'), findsNothing);
    });

    testWidgets('announces options as one group of radios', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPicker(
        tester,
        trips: [_trip(id: 'trip-1', status: 'CONFIRMED')],
        selectedTripId: 'trip-1',
        allowNone: true,
      );

      expect(
        tester.getSemantics(find.text('Unscheduled trip')),
        isSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('No shopping trip')),
        isSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets(
      'unselected radios and a proposal status stay legible and neutral',
      (tester) async {
        await _pumpPicker(
          tester,
          trips: [_trip(id: 'trip-1')],
          selectedTripId: null,
        );

        final tile = tester.widget<RadioListTile<String>>(
          find.byType(RadioListTile<String>),
        );
        final unselected = tile.fillColor!.resolve(const <WidgetState>{})!;
        expect(_contrast(unselected, PantryPalTheme.paper), greaterThan(3));

        final status = tester.widget<Text>(find.text('Proposal'));
        expect(status.style?.color, isNot(PantryPalTheme.tomato));
        expect(
          _contrast(status.style!.color!, PantryPalTheme.paper),
          greaterThan(4.5),
        );
      },
    );
  });
}
