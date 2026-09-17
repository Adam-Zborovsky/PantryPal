import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for ActivityApi
void main() {
  final instance = PantrypalApi().getActivityApi();

  group(ActivityApi, () {
    //Future activityControllerList(String householdId, String limit) async
    test('test activityControllerList', () async {
      // TODO
    });
  });
}
