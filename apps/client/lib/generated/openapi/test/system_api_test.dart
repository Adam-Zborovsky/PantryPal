import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';


/// tests for SystemApi
void main() {
  final instance = PantrypalApi().getSystemApi();

  group(SystemApi, () {
    //Future healthControllerLive() async
    test('test healthControllerLive', () async {
      // TODO
    });

    //Future healthControllerReady() async
    test('test healthControllerReady', () async {
      // TODO
    });

  });
}
