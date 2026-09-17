import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/shared/status_tone.dart';

void main() {
  test('recipe readiness uses plain wording, never the raw enum', () {
    expect(humanStatusLabel('SHOPPING_READY'), 'Ready to shop');
    expect(humanStatusLabel('COOK_READY'), 'Ready to cook');
    expect(humanStatusLabel('NEEDS_REVIEW'), 'Needs review');
    expect(humanStatusLabel('DRAFT'), 'Draft');
  });
}
