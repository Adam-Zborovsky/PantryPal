import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for ArchiveApi
void main() {
  final instance = PantrypalApi().getArchiveApi();

  group(ArchiveApi, () {
    //Future archiveControllerList(String householdId) async
    test('test archiveControllerList', () async {
      // TODO
    });
  });
}
