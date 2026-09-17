import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

// tests for CreateCookingInstanceDto
void main() {
  final instance = CreateCookingInstanceDtoBuilder();
  // TODO add properties to the builder and call build()

  group(CreateCookingInstanceDto, () {
    // String recipeId
    test('to test the property `recipeId`', () async {
      // TODO
    });

    // Desired serving count, encoded as a positive decimal.
    // String targetServings
    test('to test the property `targetServings`', () async {
      // TODO
    });

    // ISO 8601 cooking date and time. Omit for Quick Cook.
    // String cookingDate
    test('to test the property `cookingDate`', () async {
      // TODO
    });

    // String shoppingTripId
    test('to test the property `shoppingTripId`', () async {
      // TODO
    });

    // String assignmentMode (default value: 'AUTOMATIC')
    test('to test the property `assignmentMode`', () async {
      // TODO
    });
  });
}
