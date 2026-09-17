import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/recipes/recipe_review_page.dart';

RecipeReview _review(String readiness) => RecipeReview.fromJson({
  'recipe': {'id': 'recipe-1', 'readiness': readiness, 'revision': 1},
  'version': {'title': 'Garlic pasta', 'originalServings': '2'},
  'ingredients': const [],
  'instructions': const ['Boil pasta.'],
});

class _SavingRepository extends SessionRepository {
  @override
  Future<RecipeReview> recipeReview(String recipeId) async =>
      _review('NEEDS_REVIEW');

  @override
  Future<RecipeReview> saveRecipeReview(RecipeReview review) async =>
      _review('SHOPPING_READY');
}

void main() {
  testWidgets('saving a review closes the page and reports the save', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(_SavingRepository()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const RecipeReviewPage(recipeId: 'recipe-1'),
                  ),
                );
              },
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    final save = find.text('Save recipe review');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find
          .descendant(
            of: find.byType(RecipeReviewPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byType(RecipeReviewPage), findsNothing);
    expect(result, isTrue);
  });
}
