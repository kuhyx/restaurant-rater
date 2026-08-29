/// Prices: parsing what gets typed at a table, and printing it back.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/money.dart';

void main() {
  group('formatPln', () {
    test('drops the decimals on a whole number of złoty', () {
      expect(formatPln(2400), '24 zł');
    });

    test('prints grosz with a comma, padded to two digits', () {
      expect(formatPln(2450), '24,50 zł');
      expect(formatPln(2405), '24,05 zł');
    });

    test('handles zero and negatives', () {
      expect(formatPln(0), '0 zł');
      expect(formatPln(-2450), '-24,50 zł');
    });
  });

  group('parsePln', () {
    test('accepts a bare number', () {
      expect(parsePln('24'), 2400);
    });

    test('accepts a comma or a dot as the separator', () {
      expect(parsePln('24,50'), 2450);
      expect(parsePln('24.50'), 2450);
    });

    test('reads one decimal digit as tenths, not hundredths', () {
      // 24,5 zł is 24 złoty 50 grosz. Reading it as 24,05 would be wrong by a
      // factor of ten on a price people routinely type that way.
      expect(parsePln('24,5'), 2450);
    });

    test('tolerates the unit and stray spaces', () {
      expect(parsePln('24 zł'), 2400);
      expect(parsePln('24zl'), 2400);
      expect(parsePln(' 24 ZŁ '), 2400);
      expect(parsePln('24 zł'), 2400, reason: 'non-breaking space');
    });

    test('returns null for blank input, which means "no price"', () {
      expect(parsePln(''), isNull);
      expect(parsePln('   '), isNull);
      expect(parsePln('zł'), isNull);
    });

    test('returns null rather than throwing on nonsense', () {
      // This parses a field mid-typing; a throw would have to be caught on
      // every keystroke.
      expect(parsePln('abc'), isNull);
      expect(parsePln('12,34,56'), isNull);
      expect(parsePln('-5'), isNull);
    });

    test('rejects more than two decimals instead of rounding', () {
      // 12.345 is far likelier a mistyped price than a request to round, and
      // silently truncating it to 12,34 would hide the typo.
      expect(parsePln('12.345'), isNull);
    });

    test('round-trips through formatPln', () {
      for (final grosz in <int>[0, 1, 99, 100, 2400, 2450, 199999]) {
        expect(parsePln(formatPln(grosz)), grosz, reason: 'for $grosz');
      }
    });
  });
}
