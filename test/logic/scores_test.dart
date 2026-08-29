/// Overall scores: derived, never stored.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/tasting.dart';

import '../support/builders.dart';

void main() {
  test('overall is the plain mean of the three axes', () {
    // The two dishes from the original note, to the decimal.
    expect(
      overallOf(aTasting(taste: 7, smell: 6, looks: 4)),
      closeTo(5.67, 0.01),
    );
    expect(overallOf(aTasting(taste: 3, smell: 6, looks: 6)), 5.0);
  });

  test('meanOverall is null for no tastings, not zero', () {
    // "Never eaten" and "scored zero" are opposite facts; a caller that
    // cannot tell them apart ranks the unknown dish as the worst on the menu.
    expect(meanOverall(const <Tasting>[]), isNull);
  });

  test('meanOverall averages across tastings', () {
    expect(
      meanOverall(<Tasting>[
        aTasting(taste: 9, smell: 9, looks: 9),
        aTasting(taste: 3, smell: 3, looks: 3),
      ]),
      6.0,
    );
  });

  test('formatScore gives one decimal with a comma', () {
    expect(formatScore(5.0), '5,0');
    expect(formatScore(5.666), '5,7');
  });

  test('clampScore holds the 0-10 range', () {
    expect(clampScore(-3), kMinScore);
    expect(clampScore(99), kMaxScore);
    expect(clampScore(7), 7);
  });
}
