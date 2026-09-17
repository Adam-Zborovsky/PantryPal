import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/trips/shopping_item_breakdown.dart';

void main() {
  testWidgets(
    'shows exact amounts, per-recipe originals, and the estimate note',
    (tester) async {
      final item = HouseholdCollectionItem({
        'displayName': 'Flour',
        'status': 'NEED_TO_BUY',
        'unmeasured': false,
        'demand': [
          {'dimension': 'MASS', 'unit': 'g', 'min': '300', 'max': '300'},
          {'dimension': 'VOLUME', 'unit': 'ml', 'min': '480', 'max': '480'},
        ],
        'estimate': {
          'amount': '554.4',
          'unit': 'g',
          'buy': {'count': 1, 'size': '1000', 'unit': 'g'},
          'crossesDimension': true,
        },
        'contributions': [
          {
            'recipeTitle': 'Pancakes',
            'quantityMin': '2',
            'quantityMax': null,
            'unit': 'cups',
          },
          {
            'recipeTitle': 'Bread',
            'quantityMin': '300',
            'quantityMax': null,
            'unit': 'g',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ShoppingItemBreakdown(item: item)),
        ),
      );

      expect(find.text('Exact amounts'), findsOneWidget);
      expect(find.text('300 g + 480 ml'), findsOneWidget);
      expect(find.text('Pancakes'), findsOneWidget);
      expect(find.text('2 cups'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('300 g'), findsOneWidget);
      expect(
        find.text(
          'Estimate uses a typical weight for flour, so check the pack.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('explains a missing contribution list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShoppingItemBreakdown(
            item: HouseholdCollectionItem({'demand': [], 'unmeasured': true}),
          ),
        ),
      ),
    );
    expect(find.text('No recipe contribution recorded.'), findsOneWidget);
  });

  testWidgets('ignores a malformed contribution list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShoppingItemBreakdown(
            item: HouseholdCollectionItem({
              'demand': [],
              'unmeasured': true,
              'contributions': 'not a list',
            }),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No recipe contribution recorded.'), findsOneWidget);
  });
}
