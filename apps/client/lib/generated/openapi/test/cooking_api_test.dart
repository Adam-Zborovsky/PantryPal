import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for CookingApi
void main() {
  final instance = PantrypalApi().getCookingApi();

  group(CookingApi, () {
    //Future cookingControllerCreate(String householdId, CreateCookingInstanceDto createCookingInstanceDto) async
    test('test cookingControllerCreate', () async {
      // TODO
    });

    //Future cookingControllerList(String householdId) async
    test('test cookingControllerList', () async {
      // TODO
    });
  });
}
