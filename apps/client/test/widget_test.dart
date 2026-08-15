import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/main.dart';

void main() {
  testWidgets('shows the PantryPal home shell', (tester) async {
    await tester.pumpWidget(const PantryPalApp());

    expect(find.text('PantryPal'), findsOneWidget);
    expect(find.text('Good food, clearly planned.'), findsOneWidget);
    expect(find.text('Import a recipe'), findsOneWidget);
  });
}
