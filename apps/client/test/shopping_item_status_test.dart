import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/trips/shopping_item_status.dart';

void main() {
  group('shoppingItemStatus', () {
    test('maps every API status to a human verb label', () {
      expect(shoppingItemStatus('NEED_TO_BUY').label, 'Buy');
      expect(shoppingItemStatus('CONFIRMED_AT_HOME').label, 'Already have it');
      expect(shoppingItemStatus('CHECK_AGAIN').label, 'Check pantry');
      expect(shoppingItemStatus('PARTIALLY_AVAILABLE').label, 'Got some');
      expect(shoppingItemStatus('PURCHASED').label, 'Bought');
      expect(shoppingItemStatus('IGNORED').label, 'Skip');
    });

    test('unknown statuses fall back to the buy presentation', () {
      final fallback = shoppingItemStatus('SOMETHING_NEW');
      expect(fallback.label, 'Buy');
    });

    test('attention statuses use the attention color role, not primary', () {
      // Regression: CHECK_AGAIN / PARTIALLY_AVAILABLE used to render in a
      // seeded tertiary that was nearly indistinguishable from terracotta.
      expect(
        shoppingItemStatus('CHECK_AGAIN').colorRole,
        StatusColorRole.attention,
      );
      expect(
        shoppingItemStatus('PARTIALLY_AVAILABLE').colorRole,
        StatusColorRole.attention,
      );
      expect(
        shoppingItemStatus('NEED_TO_BUY').colorRole,
        StatusColorRole.active,
      );
      expect(
        shoppingItemStatus('CONFIRMED_AT_HOME').colorRole,
        StatusColorRole.positive,
      );
      expect(
        shoppingItemStatus('PURCHASED').colorRole,
        StatusColorRole.positive,
      );
      expect(
        shoppingItemStatus('IGNORED').colorRole,
        isNot(StatusColorRole.attention),
      );
    });

    test('every status has its own icon', () {
      const statuses = [
        'NEED_TO_BUY',
        'CONFIRMED_AT_HOME',
        'CHECK_AGAIN',
        'PARTIALLY_AVAILABLE',
        'PURCHASED',
        'IGNORED',
      ];
      final icons = statuses.map((s) => shoppingItemStatus(s).icon).toSet();
      expect(icons.length, statuses.length);
    });
  });

  testWidgets('statusColor resolves attention to the amber token', (
    tester,
  ) async {
    Color? resolved;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          resolved = statusToneColor(context, StatusColorRole.attention);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(resolved, isNotNull);
    expect(resolved!.toARGB32(), PantryPalTheme.amber.toARGB32());
  });
}
