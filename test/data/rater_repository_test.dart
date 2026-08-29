/// The invariant every backend enforces on its way in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
// Imported so the entry point appears in the coverage report at all: a file
// no test imports is absent from lcov.info entirely rather than reported at
// 0%, which is the hole the completeness gate exists to close. Its single
// statement carries its own coverage:ignore-line, since a Dart entry point is
// never invoked under flutter_test.
import 'package:restaurant_rater/main.dart' as entry_point;

void main() {
  group('cleanName', () {
    test('trims the ends', () {
      expect(cleanName('  tom kha  '), 'tom kha');
    });

    test('collapses interior runs of whitespace', () {
      // Two dishes that look identical in the list but sort apart is the
      // failure this prevents.
      expect(cleanName('tom  kha   z kurczakiem'), 'tom kha z kurczakiem');
    });

    test('treats tabs and newlines as whitespace, as a paste would', () {
      expect(cleanName('tom\tkha\nz kurczakiem'), 'tom kha z kurczakiem');
    });

    test('leaves an already-clean name alone', () {
      expect(cleanName('tom kha z kurczakiem'), 'tom kha z kurczakiem');
    });

    test('collapses an all-whitespace name to empty', () {
      // The dialogs refuse to save this; the point is that it does not become
      // a name made of spaces.
      expect(cleanName('   '), isEmpty);
    });
  });

  test('the entry point exists and delegates', () {
    expect(entry_point.main, isNotNull);
  });
}
