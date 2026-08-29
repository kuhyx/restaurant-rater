/// Progress and averages, per restaurant and per dish.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// How far through a restaurant's menu you are, and how good it has been.
@immutable
class RestaurantProgress {
  /// Creates a progress summary.
  const RestaurantProgress({
    required this.rated,
    required this.total,
    required this.mean,
  });

  /// Dishes with at least one tasting.
  final int rated;

  /// Dishes on the menu.
  final int total;

  /// Mean overall across every tasting here, or null when there are none.
  final double? mean;

  /// Whether every dish has been tried.
  bool get isComplete => total > 0 && rated == total;

  /// A short caption: `3/8 tried`, or `no dishes yet`.
  String get label => total == 0 ? 'no dishes yet' : '$rated/$total tried';
}

/// Summarises [menu] against [tastings].
RestaurantProgress progressOf({
  required List<MenuItem> menu,
  required List<Tasting> tastings,
}) {
  final ratedIds = <String>{for (final tasting in tastings) tasting.menuItemId};
  return RestaurantProgress(
    rated: menu.where((item) => ratedIds.contains(item.id)).length,
    total: menu.length,
    mean: meanOverall(tastings),
  );
}

/// The dishes with the best mean score first, unrated dishes excluded.
///
/// Unrated dishes are dropped rather than sorted last: they have no score, and
/// giving them a placeholder one would make the ranking a lie in whichever
/// direction the placeholder leaned.
List<({MenuItem item, double score})> rankedDishes({
  required List<MenuItem> menu,
  required List<Tasting> tastings,
}) {
  final ranked = <({MenuItem item, double score})>[];
  for (final item in menu) {
    final score = meanOverall(
      tastings.where((tasting) => tasting.menuItemId == item.id),
    );
    if (score != null) ranked.add((item: item, score: score));
  }
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.item.name.compareTo(b.item.name);
  });
  return ranked;
}
