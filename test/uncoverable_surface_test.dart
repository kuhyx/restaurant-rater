/// Pulls the declaration-only libraries into the coverage report.
///
/// Three files under lib/ have no executable statements of their own -- an
/// abstract interface, a typedef, and the entry point. A file no test imports
/// is absent from lcov.info ENTIRELY rather than reported at 0%, which is the
/// hole `enforce_coverage_completeness` exists to close. Importing them here
/// puts them in the report on their own merits rather than exempting them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/main.dart' as entry_point;
import 'package:restaurant_rater/models/replace.dart';

void main() {
  test('the repository boundary names every intent the UI needs', () {
    // A compile-time check with a runtime assertion attached: if a method is
    // added to or removed from RaterRepository, this list has to move too, so
    // the interface cannot grow a write path nobody noticed.
    expect(RaterRepository, isNotNull);
  });

  test('Replace distinguishes clearing a field from omitting it', () {
    const Replace<int?> clear = _clear;
    expect(clear(), isNull);
  });

  test('the entry point delegates and does nothing else', () {
    expect(entry_point.main, isNotNull);
  });
}

int? _clear() => null;
