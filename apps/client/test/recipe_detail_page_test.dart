import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/recipes/recipe_detail_page.dart';
import 'package:pantry_pal/features/recipes/recipe_review_page.dart';
import 'package:pantry_pal/features/shared/trip_picker.dart';
import 'package:pantry_pal/features/trips/shop_page.dart';

typedef _CreatedMeal = ({
  String recipeId,
  String targetServings,
  String? cookingDate,
  String? shoppingTripId,
});

Map<String, dynamic> _recipeJson({
  required String originalServings,
  required int revision,
  required List<Map<String, dynamic>> ingredients,
  required List<String> instructions,
}) => {
  'recipe': {
    'id': 'recipe-1',
    'readiness': 'NEEDS_REVIEW',
    'revision': revision,
  },
  'version': {'title': 'Garlic pasta', 'originalServings': originalServings},
  'ingredients': ingredients,
  'instructions': instructions,
};

class _FakeRepository extends SessionRepository {
  _FakeRepository({
    this.originalServings = '4',
    this.trips = const [],
    this.failFirstLoad = false,
    this.saveConflict = false,
    this.createStateError = false,
  });

  final String originalServings;
  final List<HouseholdCollectionItem> trips;
  bool failFirstLoad;
  final bool saveConflict;
  final bool createStateError;
  final saved = <Map<String, dynamic>>[];
  final created = <_CreatedMeal>[];
  var loads = 0;

  @override
  Future<RecipeReview> recipeReview(String recipeId) async {
    loads++;
    if (failFirstLoad) {
      failFirstLoad = false;
      throw StateError('offline');
    }
    return RecipeReview.fromJson(
      _recipeJson(
        originalServings: originalServings,
        revision: 1,
        ingredients: [
          {
            'name': 'flour',
            'quantityMin': '2',
            'originalUnit': 'cups',
            'preparationNote': 'sifted',
            'classification': 'REQUIRED',
            'includeInShopping': true,
          },
          {
            'name': 'garlic',
            'quantityMin': '3',
            'originalUnit': 'cloves',
            'classification': 'REQUIRED',
            'includeInShopping': true,
          },
        ],
        instructions: ['Boil the pasta in salted water.', 'Toss with garlic.'],
      ),
    );
  }

  @override
  Future<RecipeReview> saveRecipeReview(RecipeReview review) async {
    if (saveConflict) {
      final options = RequestOptions(path: '/recipes/recipe-1/review');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 409),
      );
    }
    final body = review.toSaveJson();
    saved.add(body);
    return RecipeReview.fromJson(
      _recipeJson(
        originalServings: review.originalServings,
        revision: 2,
        ingredients: [
          for (final item in body['ingredients'] as List)
            Map<String, dynamic>.from(item as Map),
        ],
        instructions: List<String>.from(body['instructions'] as List),
      ),
    );
  }

  @override
  Future<List<HouseholdCollectionItem>> shoppingTrips() async => trips;

  @override
  Future<List<HouseholdCollectionItem>> cookingInstances() async => const [];

  @override
  Future<HouseholdCollectionItem> shoppingTripDetail(String tripId) async =>
      HouseholdCollectionItem({'id': tripId, 'status': 'CONFIRMED'});

  @override
  Future<void> createCookingInstance({
    required String recipeId,
    required String targetServings,
    String? cookingDate,
    String? shoppingTripId,
  }) async {
    if (createStateError) throw StateError('No household selected.');
    created.add((
      recipeId: recipeId,
      targetServings: targetServings,
      cookingDate: cookingDate,
      shoppingTripId: shoppingTripId,
    ));
  }
}

class _Harness {
  _Harness(this.repository);
  final _FakeRepository repository;
  bool? popResult;
}

Future<_Harness> _pumpDetail(
  WidgetTester tester, {
  _FakeRepository? repository,
}) async {
  final harness = _Harness(repository ?? _FakeRepository());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(harness.repository),
      ],
      child: MaterialApp(
        theme: PantryPalTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                harness.popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const RecipeDetailPage(recipeId: 'recipe-1'),
                  ),
                );
              },
              child: const Text('Open recipe'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open recipe'));
  await tester.pumpAndSettle();
  return harness;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

String _fieldText(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<void> _editFlourAmount(WidgetTester tester, String value) async {
  await tester.tap(find.text('flour'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('Amount'), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows the title, servings, readiness, and both actions above ingredients on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpDetail(tester);

      expect(find.text('Garlic pasta'), findsOneWidget);
      expect(find.text('Serves 4'), findsOneWidget);
      expect(find.text('Needs review'), findsOneWidget);
      final ingredientsTop = tester.getTopLeft(find.text('Ingredients')).dy;
      for (final label in ['Add to shopping trip', 'Plan a meal']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThan(844), reason: '$label is on screen');
        expect(rect.bottom, lessThan(ingredientsTop));
      }
    },
  );

  testWidgets('ingredient rows stay compact until a row is tapped', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.text('2 cups'), findsOneWidget);
    expect(find.text('flour'), findsOneWidget);
    expect(find.text('sifted'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('flour'));
    await tester.pumpAndSettle();

    for (final label in ['Amount', 'Up to', 'Unit', 'Name', 'Note']) {
      expect(_field(label), findsOneWidget, reason: '$label field');
    }
    expect(find.text('Add to shopping list'), findsOneWidget);
    expect(_fieldText(tester, 'Amount'), '2');
  });

  testWidgets('collapsing the ingredients section hides its rows', (
    tester,
  ) async {
    await _pumpDetail(tester);

    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
    expect(find.text('flour'), findsNothing);
    expect(find.text('2 cups'), findsNothing);

    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
    expect(find.text('flour'), findsOneWidget);
  });

  testWidgets('steps show their first line and expand to an edit field', (
    tester,
  ) async {
    await _pumpDetail(tester);
    final scrollable = find
        .descendant(
          of: find.byType(RecipeDetailPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final step = find.text('Boil the pasta in salted water.');
    await tester.scrollUntilVisible(step, 200, scrollable: scrollable);

    expect(find.text('No steps yet.'), findsNothing);
    expect(_field('Step 1'), findsNothing);
    await tester.tap(step);
    await tester.pumpAndSettle();
    expect(_field('Step 1'), findsOneWidget);
  });

  testWidgets(
    'an edit shows the unsaved bar, and Save sends it and hides the bar',
    (tester) async {
      final harness = await _pumpDetail(tester);
      expect(find.text('Unsaved changes'), findsNothing);

      await _editFlourAmount(tester, '3');
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('3 cups'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final ingredients =
          harness.repository.saved.single['ingredients'] as List;
      expect((ingredients.first as Map)['quantityMin'], '3');
      expect(find.text('Unsaved changes'), findsNothing);
      expect(find.text('Recipe saved.'), findsOneWidget);
      expect(find.text('3 cups'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RecipeDetailPage), findsNothing);
      expect(harness.popResult, isTrue);
    },
  );

  testWidgets('Discard restores the loaded recipe', (tester) async {
    final harness = await _pumpDetail(tester);

    await _editFlourAmount(tester, '3');
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('2 cups'), findsOneWidget);
    expect(_fieldText(tester, 'Amount'), '2');
    expect(harness.repository.saved, isEmpty);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final harness = await _pumpDetail(tester);
    await _editFlourAmount(tester, '3');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailPage), findsNothing);
    expect(harness.popResult, isFalse);
  });

  testWidgets(
    'Add to shopping trip lists open trips and adds to the chosen one',
    (tester) async {
      final scheduledTrip = HouseholdCollectionItem({
        'id': 'trip-1',
        'status': 'PROPOSED',
        'scheduledFor': DateTime(2026, 9, 19, 10).toUtc().toIso8601String(),
      });
      final completedTrip = HouseholdCollectionItem({
        'id': 'trip-3',
        'status': 'COMPLETED',
        'scheduledFor': DateTime(2026, 9, 2, 10).toUtc().toIso8601String(),
      });
      final harness = await _pumpDetail(
        tester,
        repository: _FakeRepository(
          trips: [
            scheduledTrip,
            const HouseholdCollectionItem({
              'id': 'trip-2',
              'status': 'CONFIRMED',
              'scheduledFor': null,
            }),
            completedTrip,
          ],
        ),
      );

      await tester.tap(find.text('Add to shopping trip'));
      await tester.pumpAndSettle();

      expect(find.text(tripPickerLabel(scheduledTrip)), findsOneWidget);
      expect(find.text('Unscheduled trip'), findsOneWidget);
      expect(find.text(tripPickerLabel(completedTrip)), findsNothing);

      await tester.tap(find.text('Unscheduled trip'));
      await tester.tap(find.text('Add to trip'));
      await tester.pumpAndSettle();

      expect(harness.repository.created, [
        (
          recipeId: 'recipe-1',
          targetServings: '4',
          cookingDate: null,
          shoppingTripId: 'trip-2',
        ),
      ]);
      expect(find.text('Add to trip'), findsNothing);
    },
  );

  testWidgets('Add to shopping trip explains when no trips are open', (
    tester,
  ) async {
    await _pumpDetail(tester);

    await tester.tap(find.text('Add to shopping trip'));
    await tester.pumpAndSettle();

    expect(
      find.text('No open shopping trips. Create one in Shop.'),
      findsOneWidget,
    );
    expect(find.text('Add to trip'), findsNothing);
  });

  testWidgets('adding to a trip is blocked until the recipe has servings', (
    tester,
  ) async {
    final harness = await _pumpDetail(
      tester,
      repository: _FakeRepository(
        originalServings: '',
        trips: const [
          HouseholdCollectionItem({'id': 'trip-2', 'status': 'CONFIRMED'}),
        ],
      ),
    );
    expect(find.text('Servings not set'), findsOneWidget);

    await tester.tap(find.text('Add to shopping trip'));
    await tester.pumpAndSettle();

    expect(
      find.text('Set the recipe’s servings before adding it to a trip.'),
      findsOneWidget,
    );
    expect(find.text('Add to trip'), findsNothing);
    expect(harness.repository.created, isEmpty);
  });

  testWidgets('Plan a meal adds a meal at 18:00 today with no trip', (
    tester,
  ) async {
    final harness = await _pumpDetail(tester);

    await tester.tap(find.text('Plan a meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(harness.repository.created, [
      (
        recipeId: 'recipe-1',
        targetServings: '4',
        cookingDate: DateTime(
          now.year,
          now.month,
          now.day,
          18,
        ).toUtc().toIso8601String(),
        shoppingTripId: null,
      ),
    ]);
    expect(find.text('Add meal'), findsNothing);
  });

  testWidgets('the servings row expands to a field and saves the new value', (
    tester,
  ) async {
    final harness = await _pumpDetail(tester);
    expect(_field('Servings'), findsNothing);

    await tester.tap(find.text('Serves 4'));
    await tester.pumpAndSettle();
    expect(_field('Servings'), findsOneWidget);
    expect(_fieldText(tester, 'Servings'), '4');

    await tester.enterText(_field('Servings'), '6');
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Serves 6'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(harness.repository.saved.single['originalServings'], '6');
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets(
    'saving servings on a recipe without them clears the trip guard',
    (tester) async {
      await _pumpDetail(
        tester,
        repository: _FakeRepository(
          originalServings: '',
          trips: const [
            HouseholdCollectionItem({'id': 'trip-2', 'status': 'CONFIRMED'}),
          ],
        ),
      );

      await tester.tap(find.text('Servings not set'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Servings'), '4');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Serves 4'), findsOneWidget);

      await tester.tap(find.text('Add to shopping trip'));
      await tester.pumpAndSettle();

      expect(
        find.text('Set the recipe’s servings before adding it to a trip.'),
        findsNothing,
      );
      expect(find.text('Add to trip'), findsOneWidget);
    },
  );

  testWidgets('disclosure rows announce one labelled node each', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpDetail(tester);

    expect(find.bySemanticsLabel('Serves 4'), findsOneWidget);
    expect(find.bySemanticsLabel('2 cups flour, sifted'), findsOneWidget);
    expect(find.bySemanticsLabel('3 cloves garlic'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await _pumpDetail(tester, repository: _FakeRepository(failFirstLoad: true));

    expect(find.text('Could not load this recipe.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Garlic pasta'), findsOneWidget);
  });

  testWidgets('disclosure rows expose a tap action that toggles them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await _pumpDetail(tester);

    for (final label in [
      'Serves 4',
      'Ingredients, 2',
      '2 cups flour, sifted',
      'Steps, 2',
      'Step 1, Boil the pasta in salted water.',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
    }

    expect(_field('Amount'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('2 cups flour, sifted'));
    await tester.pumpAndSettle();
    expect(_field('Amount'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'Refresh after a save conflict confirms before discarding the draft',
    (tester) async {
      final repository = _FakeRepository(saveConflict: true);
      await _pumpDetail(tester, repository: repository);
      await _editFlourAmount(tester, '3');

      Future<void> saveAndRefresh() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This recipe changed elsewhere. Refresh to see the latest version.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(SnackBarAction, 'Refresh'));
        await tester.pumpAndSettle();
      }

      await saveAndRefresh();
      expect(
        find.text('Discard your changes and load the latest version?'),
        findsOneWidget,
      );
      final loadsBefore = repository.loads;
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(repository.loads, loadsBefore);
      expect(find.text('3 cups'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);

      await saveAndRefresh();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.loads, loadsBefore + 1);
      expect(find.text('2 cups'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsNothing);
    },
  );

  testWidgets('Edit full recipe opens the review page and reloads on save', (
    tester,
  ) async {
    final harness = await _pumpDetail(tester);
    final loadsBefore = harness.repository.loads;

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit full recipe'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeReviewPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(RecipeReviewPage))).pop(true);
    await tester.pumpAndSettle();
    expect(find.byType(RecipeReviewPage), findsNothing);
    expect(harness.repository.loads, greaterThan(loadsBefore + 1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(harness.popResult, isTrue);
  });

  testWidgets('Edit full recipe waits until unsaved changes are resolved', (
    tester,
  ) async {
    await _pumpDetail(tester);
    await _editFlourAmount(tester, '3');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit full recipe'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeReviewPage), findsNothing);
    expect(find.text('Save or discard your changes first.'), findsOneWidget);
  });

  testWidgets('adding to a trip or planning a meal refreshes Shop', (
    tester,
  ) async {
    final harness = await _pumpDetail(
      tester,
      repository: _FakeRepository(
        trips: const [
          HouseholdCollectionItem({'id': 'trip-2', 'status': 'CONFIRMED'}),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecipeDetailPage)),
    );
    final refreshed = <String>[];
    final subscriptions = [
      container.listen(shopTripsProvider, (_, _) => refreshed.add('trips')),
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

    await tester.tap(find.text('Add to shopping trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unscheduled trip'));
    await tester.tap(find.text('Add to trip'));
    await tester.pumpAndSettle();
    expect(harness.repository.created, hasLength(1));
    expect(refreshed, containsAll(['trips', 'trip-2']));

    refreshed.clear();
    await tester.tap(find.text('Plan a meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();
    expect(harness.repository.created, hasLength(2));
    expect(refreshed, containsAll(['trips', 'trip-2']));
  });

  _FakeRepository unsendableRepository() => _FakeRepository(
    createStateError: true,
    trips: const [
      HouseholdCollectionItem({'id': 'trip-2', 'status': 'CONFIRMED'}),
    ],
  );

  testWidgets('adding to a trip that cannot be sent shows the error', (
    tester,
  ) async {
    await _pumpDetail(tester, repository: unsendableRepository());

    await tester.tap(find.text('Add to shopping trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unscheduled trip'));
    await tester.tap(find.text('Add to trip'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not add this recipe to the trip. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Add to trip'), findsOneWidget);
  });

  testWidgets('planning a meal that cannot be sent shows the error', (
    tester,
  ) async {
    await _pumpDetail(tester, repository: unsendableRepository());

    await tester.tap(find.text('Plan a meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not add this meal. Check the servings and try again.'),
      findsOneWidget,
    );
    expect(find.text('Add meal'), findsOneWidget);
  });
}
