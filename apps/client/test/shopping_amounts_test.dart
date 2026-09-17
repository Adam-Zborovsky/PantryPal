import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/trips/shopping_amounts.dart';

void main() {
  group('formatAmount', () {
    test('switches to kg and L at 1000 and trims zeros', () {
      expect(formatAmount(300, 'g'), '300 g');
      expect(formatAmount(1200, 'g'), '1.2 kg');
      expect(formatAmount(1000, 'ml'), '1 L');
      expect(formatAmount(22.5, 'ml'), '22.5 ml');
    });

    test('pluralizes count units', () {
      expect(formatAmount(1, 'head'), '1 head');
      expect(formatAmount(4, 'clove'), '4 cloves');
      expect(formatAmount(2, 'pinch'), '2 pinches');
      expect(formatAmount(0.4, 'head'), '0.4 heads');
    });
  });

  test('formatRange shows both ends only when they differ', () {
    expect(formatRange(200, 200, 'g'), '200 g');
    expect(formatRange(200, 300, 'g'), '200–300 g');
    expect(formatRange(800, 1200, 'g'), '0.8–1.2 kg');
  });

  test('roundEstimate uses size bands for grams and millilitres', () {
    expect(roundEstimate(0.42, 'g'), 0.4);
    expect(roundEstimate(23, 'g'), 25);
    expect(roundEstimate(554.4, 'g'), 550);
    expect(roundEstimate(1180, 'ml'), 1200);
  });

  test('roundEstimate keeps count units to one decimal', () {
    expect(roundEstimate(12, 'piece'), 12);
    expect(roundEstimate(23, 'piece'), 23);
    expect(roundEstimate(0.42, 'head'), 0.4);
    expect(roundEstimate(137.46, 'clove'), 137.5);
  });

  group('summaries', () {
    final flour = <String, Object?>{
      'status': 'NEED_TO_BUY',
      'unmeasured': false,
      'demand': [
        {'dimension': 'MASS', 'unit': 'g', 'min': '300', 'max': '300'},
        {'dimension': 'VOLUME', 'unit': 'ml', 'min': '480', 'max': '480'},
      ],
      'estimate': {
        'approximate': true,
        'amount': '554.4',
        'unit': 'g',
        'buy': {'count': 1, 'size': '1000', 'unit': 'g'},
        'crossesDimension': true,
      },
    };

    test('prefers the estimate when present', () {
      expect(shoppingItemSummary(flour), '≈ 550 g · buy 1 × 1 kg');
    });

    test('falls back to exact amounts', () {
      expect(
        shoppingItemSummary({...flour, 'estimate': null}),
        '300 g + 480 ml',
      );
    });

    test('mentions unmeasured amounts', () {
      expect(exactSummary(const [], unmeasured: true), 'Some to taste');
      expect(
        shoppingItemSummary({...flour, 'estimate': null, 'unmeasured': true}),
        '300 g + 480 ml + some to taste',
      );
    });

    test(
      'says what is still needed when the amount at home was subtracted',
      () {
        expect(
          shoppingItemSummary({
            ...flour,
            'status': 'PARTIALLY_AVAILABLE',
            'estimate': {
              ...flour['estimate']! as Map<String, Object?>,
              'remainderApplied': true,
            },
          }),
          'Still need ≈ 550 g · buy 1 × 1 kg',
        );
      },
    );

    test(
      'shows the full estimate for partial availability without a remainder',
      () {
        expect(
          shoppingItemSummary({
            ...flour,
            'status': 'PARTIALLY_AVAILABLE',
            'estimate': {
              ...flour['estimate']! as Map<String, Object?>,
              'remainderApplied': false,
            },
          }),
          '≈ 550 g · buy 1 × 1 kg',
        );
      },
    );

    test('keeps count estimates unrounded to bands', () {
      expect(
        shoppingItemSummary({
          'status': 'NEED_TO_BUY',
          'estimate': {
            'amount': '12',
            'unit': 'piece',
            'buy': null,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        }),
        '≈ 12 pieces',
      );
    });

    test('omits the buy suggestion when there is none', () {
      final estimate = estimateFrom({
        'estimate': {
          'amount': '80',
          'unit': 'g',
          'buy': null,
          'crossesDimension': false,
        },
      })!;
      expect(estimateSummary(estimate, status: 'NEED_TO_BUY'), '≈ 80 g');
    });
  });

  test('contributionAmount formats original units', () {
    expect(
      contributionAmount({
        'quantityMin': '2',
        'quantityMax': null,
        'unit': 'cups',
      }),
      '2 cups',
    );
    expect(
      contributionAmount({
        'quantityMin': '1',
        'quantityMax': '2',
        'unit': 'tbsp',
      }),
      '1–2 tbsp',
    );
    expect(
      contributionAmount({
        'quantityMin': null,
        'quantityMax': null,
        'unit': null,
      }),
      'To taste',
    );
  });

  test('crossDimensionNote only appears for cross-dimension estimates', () {
    final cross = estimateFrom({
      'estimate': {
        'amount': '554.4',
        'unit': 'g',
        'buy': null,
        'crossesDimension': true,
      },
    })!;
    final exact = estimateFrom({
      'estimate': {
        'amount': '90',
        'unit': 'ml',
        'buy': null,
        'crossesDimension': false,
      },
    })!;
    expect(
      crossDimensionNote(cross, 'Flour'),
      'Estimate uses a typical weight for flour, so check the pack.',
    );
    expect(crossDimensionNote(exact, 'Olive oil'), isNull);
  });
}
