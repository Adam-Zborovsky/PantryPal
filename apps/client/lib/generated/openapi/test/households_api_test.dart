import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';


/// tests for HouseholdsApi
void main() {
  final instance = PantrypalApi().getHouseholdsApi();

  group(HouseholdsApi, () {
    //Future householdsControllerJoin(JoinHouseholdDto joinHouseholdDto) async
    test('test householdsControllerJoin', () async {
      // TODO
    });

    //Future householdsControllerLeave(String householdId) async
    test('test householdsControllerLeave', () async {
      // TODO
    });

    //Future householdsControllerList() async
    test('test householdsControllerList', () async {
      // TODO
    });

    //Future householdsControllerMembers(String householdId) async
    test('test householdsControllerMembers', () async {
      // TODO
    });

    //Future householdsControllerRotateCode(String householdId) async
    test('test householdsControllerRotateCode', () async {
      // TODO
    });

  });
}
