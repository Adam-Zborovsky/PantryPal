import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/main.dart';

void main() {
  testWidgets('shows the PantryPal sign-in screen', (tester) async {
    await tester.pumpWidget(const PantryPalApp());

    expect(find.text('PantryPal'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
