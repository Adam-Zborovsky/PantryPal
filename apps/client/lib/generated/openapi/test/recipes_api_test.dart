import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for RecipesApi
void main() {
  final instance = PantrypalApi().getRecipesApi();

  group(RecipesApi, () {
    //Future recipesControllerReview(String householdId, String recipeId) async
    test('test recipesControllerReview', () async {
      // TODO
    });

    //Future recipesControllerSaveReview(String householdId, String recipeId, SaveRecipeReviewDto saveRecipeReviewDto) async
    test('test recipesControllerSaveReview', () async {
      // TODO
    });
  });
}
