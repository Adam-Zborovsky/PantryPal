import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/shared/scheduling.dart';

void main() {
  group('scheduledToApi', () {
    test('emits a UTC ISO 8601 timestamp ending in Z', () {
      final value = scheduledToApi(DateTime(2026, 8, 22, 18));
      expect(value, endsWith('Z'));
      expect(value, contains('T'));
      expect(() => DateTime.parse(value), returnsNormally);
    });

    test('round-trips through DateTime.parse with the same instant', () {
      final local = DateTime(2026, 8, 22, 18);
      final parsed = DateTime.parse(scheduledToApi(local));
      expect(
        parsed.toUtc().millisecondsSinceEpoch,
        local.toUtc().millisecondsSinceEpoch,
      );
    });
  });

  group('tryParseScheduled', () {
    test('parses stored ISO timestamps', () {
      final parsed = tryParseScheduled('2026-08-22T10:00:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc().hour, 10);
    });

    test('returns local wall-clock time for a UTC timestamp', () {
      final local = DateTime(2026, 8, 22, 0, 30);
      final parsed = tryParseScheduled(local.toUtc().toIso8601String())!;
      expect(parsed.isUtc, isFalse);
      expect(
        [parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute],
        [2026, 8, 22, 0, 30],
      );
    });

    test('returns null for blank or junk input', () {
      expect(tryParseScheduled(null), isNull);
      expect(tryParseScheduled(''), isNull);
      expect(tryParseScheduled('   '), isNull);
      expect(tryParseScheduled('not a date'), isNull);
    });
  });

  group('formatScheduledForDisplay', () {
    test('renders day, date, and time without machine artifacts', () {
      final text = formatScheduledForDisplay(DateTime(2026, 8, 22, 18, 30));
      expect(text, contains('Aug'));
      expect(text, contains('18:30'));
      expect(text.contains('.000'), isFalse);
      expect(text.contains('T'), isFalse);
    });
  });
}
