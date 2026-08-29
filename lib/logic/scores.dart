/// Turning the three axes into one number.
library;

import 'package:restaurant_rater/models/tasting.dart';

/// The overall score for one tasting: the plain mean of taste, smell and looks.
///
/// Unweighted on purpose. Weighting taste heavier is defensible and would be a
/// one-line change here — which is precisely why the value is *derived* on
/// every read rather than stored on the tasting. A stored overall would have
/// to be migrated to change, and worse, two devices could merge components
/// from one side and an overall from the other and hold a number that does not
/// match its own parts.
double overallOf(Tasting tasting) =>
    (tasting.taste + tasting.smell + tasting.looks) / 3;

/// The mean overall across [tastings], or null when there are none.
///
/// Null rather than 0: "never eaten" and "scored zero" are opposite facts and
/// a caller that cannot tell them apart will rank the unknown dish as the
/// worst on the menu.
double? meanOverall(Iterable<Tasting> tastings) {
  var sum = 0.0;
  var count = 0;
  for (final tasting in tastings) {
    sum += overallOf(tasting);
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// Formats a score for display: one decimal, comma separator.
String formatScore(double score) =>
    score.toStringAsFixed(1).replaceAll('.', ',');

/// Clamps a raw slider or typed value into the 0-10 range.
int clampScore(int value) => value.clamp(kMinScore, kMaxScore);
