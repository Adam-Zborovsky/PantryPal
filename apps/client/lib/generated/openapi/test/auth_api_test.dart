import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';


/// tests for AuthApi
void main() {
  final instance = PantrypalApi().getAuthApi();

  group(AuthApi, () {
    //Future authControllerLogin(LoginDto loginDto) async
    test('test authControllerLogin', () async {
      // TODO
    });

    //Future authControllerLogout(RefreshDto refreshDto) async
    test('test authControllerLogout', () async {
      // TODO
    });

    //Future authControllerRefresh(RefreshDto refreshDto) async
    test('test authControllerRefresh', () async {
      // TODO
    });

    //Future authControllerRegister(RegisterDto registerDto) async
    test('test authControllerRegister', () async {
      // TODO
    });

  });
}
