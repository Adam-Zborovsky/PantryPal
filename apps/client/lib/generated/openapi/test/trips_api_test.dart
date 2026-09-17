import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for TripsApi
void main() {
  final instance = PantrypalApi().getTripsApi();

  group(TripsApi, () {
    //Future tripsControllerConfirm(String householdId, String tripId) async
    test('test tripsControllerConfirm', () async {
      // TODO
    });

    //Future tripsControllerCreate(String householdId, CreateShoppingTripDto createShoppingTripDto) async
    test('test tripsControllerCreate', () async {
      // TODO
    });

    //Future tripsControllerList(String householdId) async
    test('test tripsControllerList', () async {
      // TODO
    });
  });
}
