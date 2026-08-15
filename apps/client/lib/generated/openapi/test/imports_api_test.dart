import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';


/// tests for ImportsApi
void main() {
  final instance = PantrypalApi().getImportsApi();

  group(ImportsApi, () {
    //Future importsControllerCancel(String householdId, String id) async
    test('test importsControllerCancel', () async {
      // TODO
    });

    //Future importsControllerCreate(String householdId, CreateImportDto createImportDto) async
    test('test importsControllerCreate', () async {
      // TODO
    });

    //Future importsControllerGet(String householdId, String id) async
    test('test importsControllerGet', () async {
      // TODO
    });

  });
}
