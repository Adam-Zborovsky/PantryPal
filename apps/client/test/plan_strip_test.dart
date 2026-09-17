import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/planning/plan_page.dart';
import 'package:pantry_pal/features/shared/scheduling.dart';
import 'package:pantry_pal/features/trips/shop_page.dart';

class _FakeRepository extends SessionRepository {
  _FakeRepository({
    List<HouseholdCollectionItem>? instances,
    List<HouseholdCollectionItem>? trips,
    this.assignError = false,
    this.assignStateError = false,
  }) : instances = instances ?? const [],
       trips = trips ?? const [];

  List<HouseholdCollectionItem> instances;
  List<HouseholdCollectionItem> trips;
  final bool assignError;
  final bool assignStateError;
  final assignments = <(String, String?)>[];

  @override
  Future<HouseholdCollectionItem> shoppingTripDetail(String tripId) async =>
      HouseholdCollectionItem({'id': tripId, 'status': 'CONFIRMED'});

  @override
  Future<List<HouseholdCollectionItem>> cookingInstances() async => instances;

  @override
  Future<List<HouseholdCollectionItem>> shoppingTrips() async => trips;

  @override
  Future<List<HouseholdCollectionItem>> recipes() async => const [];

  @override
  Future<void> assignCookingTrip({
    required String cookingInstanceId,
    required String? shoppingTripId,
  }) async {
    if (assignStateError) throw StateError('No household selected.');
    if (assignError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/cooking/$cookingInstanceId'),
        response: Response(
          requestOptions: RequestOptions(path: '/cooking/$cookingInstanceId'),
          statusCode: 409,
        ),
      );
    }
    assignments.add((cookingInstanceId, shoppingTripId));
  }
}

HouseholdCollectionItem _meal({
  required String id,
  required DateTime cookingDate,
  String? shoppingTripId,
  String status = 'SCHEDULED',
  String title = 'Garlic pasta',
}) => HouseholdCollectionItem({
  'id': id,
  'status': status,
  // The API sends Z-suffixed UTC timestamps.
  'cookingDate': cookingDate.toUtc().toIso8601String(),
  'shoppingTripId': shoppingTripId,
  'targetServings': '2',
  'recipeSnapshot': {'title': title},
});

HouseholdCollectionItem _tripItem(
  String id, {
  String status = 'PROPOSED',
  DateTime? scheduledFor,
}) => HouseholdCollectionItem({
  'id': id,
  'status': status,
  'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
});

Future<_FakeRepository> _pumpPlan(
  WidgetTester tester, {
  List<HouseholdCollectionItem>? instances,
  List<HouseholdCollectionItem>? trips,
  bool assignError = false,
  bool assignStateError = false,
  TextScaler? textScaler,
}) async {
  final repository = _FakeRepository(
    instances: instances,
    trips: trips,
    assignError: assignError,
    assignStateError: assignStateError,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: PantryPalTheme.light(),
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const Scaffold(body: PlanPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// A local wall-clock time on [day], independent of DST and time zone.
DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

Future<void> _openChangeTrip(WidgetTester tester) async {
  await tester.tap(find.text('Garlic pasta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Change trip'));
  await tester.pumpAndSettle();
}

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

/// Finds a day cell by its configured accessibility label. `_DateCell`'s
/// Semantics is non-container, so its label is merged into an ancestor node
/// at the render layer and `find.bySemanticsLabel` cannot see it in
/// isolation; matching the widget's own `properties.label` sidesteps that.
Finder _findDay(DateTime day) {
  final label = DateFormat('EEEE, d MMMM').format(day);
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

void main() {
  late SemanticsHandle semantics;

  setUp(() {
    semantics = SemanticsBinding.instance.ensureSemantics();
  });

  tearDown(() {
    semantics.dispose();
  });

  testWidgets('shows 7 day cells for the current week initially', (
    tester,
  ) async {
    await _pumpPlan(tester);

    expect(find.text('This week'), findsOneWidget);
    final today = _today();
    for (var i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      expect(
        _findDay(day),
        findsOneWidget,
        reason: 'day $i should be visible on the first page',
      );
    }
  });

  testWidgets('tapping next reveals next week and its 8th day', (tester) async {
    await _pumpPlan(tester);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();

    expect(find.text('Next week'), findsOneWidget);
    final eighthDay = _today().add(const Duration(days: 7));
    expect(_findDay(eighthDay), findsOneWidget);
  });

  testWidgets('the strip has 3 pages max and disables next at the end', (
    tester,
  ) async {
    await _pumpPlan(tester);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('In 2 weeks'), findsNothing);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('In 2 weeks'), findsOneWidget);

    final nextButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Next week'),
        matching: find.byType(IconButton),
      ),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('selecting a day on the second page updates the day heading', (
    tester,
  ) async {
    await _pumpPlan(tester);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();

    final today = _today();
    final targetDay = today.add(const Duration(days: 9));
    await tester.tap(_findDay(targetDay));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('EEEE, d MMMM').format(targetDay)),
      findsOneWidget,
    );
  });

  testWidgets(
    'meal detail shows "Needs a shopping trip" and changing it updates the plan',
    (tester) async {
      final today = _today();
      final meal = _meal(id: 'meal-1', cookingDate: _at(today, 18));
      final trip = _tripItem('trip-1');
      final repository = await _pumpPlan(
        tester,
        instances: [meal],
        trips: [trip],
      );

      await tester.tap(find.text('Garlic pasta'));
      await tester.pumpAndSettle();
      expect(find.text('Needs a shopping trip'), findsOneWidget);

      await tester.tap(find.text('Change trip'));
      await tester.pumpAndSettle();
      expect(find.text('Unscheduled trip'), findsOneWidget);

      await tester.tap(find.text('Unscheduled trip'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.assignments, [('meal-1', 'trip-1')]);
      expect(find.text('Shopping trip updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed trip change shows a plain error and keeps the sheet open',
    (tester) async {
      final today = _today();
      final meal = _meal(id: 'meal-1', cookingDate: _at(today, 18));
      final trip = _tripItem('trip-1');
      await _pumpPlan(
        tester,
        instances: [meal],
        trips: [trip],
        assignError: true,
      );

      await tester.tap(find.text('Garlic pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unscheduled trip'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not update the shopping trip. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
    },
  );

  testWidgets('files meals under their local calendar day and time', (
    tester,
  ) async {
    final today = _today();
    final tomorrow = today.add(const Duration(days: 1));
    await _pumpPlan(
      tester,
      instances: [
        _meal(id: 'early', cookingDate: _at(today, 0, 30), title: 'Early oats'),
        _meal(id: 'late', cookingDate: _at(today, 23, 30), title: 'Late soup'),
        _meal(
          id: 'next',
          cookingDate: _at(tomorrow, 0, 30),
          title: 'Tomorrow toast',
        ),
      ],
    );

    expect(find.text('Early oats'), findsOneWidget);
    expect(find.text('Late soup'), findsOneWidget);
    expect(find.text('Tomorrow toast'), findsNothing);
    expect(find.text('12:30 AM · Serves 2'), findsOneWidget);
    expect(find.text('11:30 PM · Serves 2'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('the date strip grows with ${scale}x text without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpPlan(tester, textScaler: TextScaler.linear(scale));

      expect(tester.takeException(), isNull);
      expect(_findDay(_today()), findsOneWidget);
    });
  }

  testWidgets('Save stays disabled until a different trip is chosen', (
    tester,
  ) async {
    final today = _today();
    await _pumpPlan(
      tester,
      instances: [
        _meal(
          id: 'meal-1',
          cookingDate: _at(today, 18),
          shoppingTripId: 'trip-1',
        ),
      ],
      trips: [_tripItem('trip-1')],
    );

    await _openChangeTrip(tester);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('No shopping trip'));
    await tester.pumpAndSettle();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Unscheduled trip'));
    await tester.pumpAndSettle();
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets(
    'a meal on a cancelled trip needs a trip and starts with no selection',
    (tester) async {
      final today = _today();
      final repository = await _pumpPlan(
        tester,
        instances: [
          _meal(
            id: 'meal-1',
            cookingDate: _at(today, 18),
            shoppingTripId: 'trip-old',
          ),
        ],
        trips: [
          _tripItem('trip-old', status: 'CANCELLED', scheduledFor: today),
          _tripItem('trip-1'),
        ],
      );

      await tester.tap(find.text('Garlic pasta'));
      await tester.pumpAndSettle();
      expect(find.text('Needs a shopping trip'), findsOneWidget);

      await tester.tap(find.text('Change trip'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('No shopping trip')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.text('Unscheduled trip')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );

      await tester.tap(find.text('Unscheduled trip'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.assignments, [('meal-1', 'trip-1')]);
    },
  );

  testWidgets('clearing a trip is offered even when no trips are open', (
    tester,
  ) async {
    final today = _today();
    final repository = await _pumpPlan(
      tester,
      instances: [
        _meal(
          id: 'meal-1',
          cookingDate: _at(today, 18),
          shoppingTripId: 'trip-old',
        ),
      ],
      trips: [_tripItem('trip-old', status: 'COMPLETED', scheduledFor: today)],
    );

    await _openChangeTrip(tester);
    expect(
      find.text('No open shopping trips. Create one in Shop.'),
      findsOneWidget,
    );
    expect(find.text('No shopping trip'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.assignments, [('meal-1', null)]);
  });

  testWidgets('changing a trip refreshes the Shop trip list and details', (
    tester,
  ) async {
    final today = _today();
    await _pumpPlan(
      tester,
      instances: [
        _meal(
          id: 'meal-1',
          cookingDate: _at(today, 18),
          shoppingTripId: 'trip-1',
        ),
      ],
      trips: [
        _tripItem('trip-1'),
        _tripItem('trip-2', status: 'CONFIRMED', scheduledFor: _at(today, 9)),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanPage)),
    );
    final refreshed = <String>[];
    final subscriptions = [
      container.listen(shopTripsProvider, (_, _) => refreshed.add('trips')),
      container.listen(
        tripDetailProvider('trip-1'),
        (_, _) => refreshed.add('trip-1'),
      ),
      container.listen(
        tripDetailProvider('trip-2'),
        (_, _) => refreshed.add('trip-2'),
      ),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    await tester.pumpAndSettle();
    refreshed.clear();

    await _openChangeTrip(tester);
    await tester.tap(find.text(formatScheduledForDisplay(_at(today, 9))));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(refreshed, containsAll(['trips', 'trip-1', 'trip-2']));
  });

  testWidgets('a trip change that cannot be sent shows the error', (
    tester,
  ) async {
    final today = _today();
    await _pumpPlan(
      tester,
      instances: [_meal(id: 'meal-1', cookingDate: _at(today, 18))],
      trips: [_tripItem('trip-1')],
      assignStateError: true,
    );

    await _openChangeTrip(tester);
    await tester.tap(find.text('Unscheduled trip'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update the shopping trip. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsOneWidget);
  });
}
