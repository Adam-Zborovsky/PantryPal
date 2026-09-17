import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/shared/sticker_chip.dart';

void main() {
  Future<Finder> pumpChip(WidgetTester tester, StickerChip chip) async {
    late Finder chipFinder;
    await tester.pumpWidget(
      MaterialApp(
        theme: PantryPalTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              chipFinder = find.byWidget(chip);
              return Center(child: chip);
            },
          ),
        ),
      ),
    );
    return chipFinder;
  }

  testWidgets('renders its label as bold small text', (tester) async {
    await pumpChip(
      tester,
      const StickerChip(label: 'Buy', color: PantryPalTheme.tomato),
    );
    final text = tester.widget<Text>(find.text('Buy'));
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(text.style!.fontSize, lessThanOrEqualTo(12));
  });

  testWidgets('is a pill with a thick ink border and tinted fill', (
    tester,
  ) async {
    await pumpChip(
      tester,
      const StickerChip(label: 'Bought', color: PantryPalTheme.green),
    );
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text('Bought'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(999));
    final border = decoration.border! as Border;
    expect(border.top.width, greaterThanOrEqualTo(1.5));
    expect(border.top.color, PantryPalTheme.ink);
    expect(decoration.color, isNot(Colors.transparent));
  });

  testWidgets('shows an optional leading icon', (tester) async {
    await pumpChip(
      tester,
      const StickerChip(
        label: 'Check pantry',
        color: PantryPalTheme.amber,
        icon: Icons.help_outline,
      ),
    );
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });
}
