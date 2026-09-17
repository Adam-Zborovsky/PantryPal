import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for NotificationsApi
void main() {
  final instance = PantrypalApi().getNotificationsApi();

  group(NotificationsApi, () {
    //Future notificationsControllerList(String householdId) async
    test('test notificationsControllerList', () async {
      // TODO
    });

    //Future notificationsControllerMarkRead(String householdId, String notificationId) async
    test('test notificationsControllerMarkRead', () async {
      // TODO
    });
  });
}
