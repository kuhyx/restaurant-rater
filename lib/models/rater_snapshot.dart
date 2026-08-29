/// Everything the app knows, as one immutable read.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/logic/menu_order.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// A consistent view of every restaurant, dish and tasting at one instant.
///
/// One read gives a screen everything it needs. The alternative — a repository
/// method per query — would have each screen awaiting several reads that can
/// interleave with a sync merge, so a menu could render against one version of
/// the log and its tastings against another, and a dish would flicker between
/// rated and unrated for no reason the user could see.
@immutable
class RaterSnapshot {
  /// Creates a snapshot. The lists are stored as given; callers must not
  /// mutate them afterwards.
  const RaterSnapshot({
    required this.restaurants,
    required this.menuItems,
    required this.tastings,
  });

  /// An empty world: no restaurants, no dishes, no ratings.
  static const RaterSnapshot empty = RaterSnapshot(
    restaurants: <Restaurant>[],
    menuItems: <MenuItem>[],
    tastings: <Tasting>[],
  );

  /// Every live restaurant.
  final List<Restaurant> restaurants;

  /// Every live menu item, across all restaurants.
  final List<MenuItem> menuItems;

  /// Every live tasting, across all restaurants.
  final List<Tasting> tastings;

  /// Whether nothing has been recorded yet.
  bool get isEmpty =>
      restaurants.isEmpty && menuItems.isEmpty && tastings.isEmpty;

  /// The restaurant with [id], or null when it is absent or deleted.
  Restaurant? restaurantById(String id) {
    for (final restaurant in restaurants) {
      if (restaurant.id == id) return restaurant;
    }
    return null;
  }

  /// The dish with [id], or null when it is absent or deleted.
  MenuItem? menuItemById(String id) {
    for (final item in menuItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// [restaurantId]'s menu, in the order the dishes were entered.
  List<MenuItem> menuOf(String restaurantId) => sortedByOrderKey(
    menuItems.where((item) => item.restaurantId == restaurantId),
  );

  /// Every tasting recorded at [restaurantId], in no particular order.
  List<Tasting> tastingsOf(String restaurantId) => tastings
      .where((tasting) => tasting.restaurantId == restaurantId)
      .toList(growable: false);

  /// Every tasting of one dish, newest first.
  List<Tasting> tastingsOfItem(String menuItemId) {
    final matches =
        tastings.where((tasting) => tasting.menuItemId == menuItemId).toList()
          ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    return matches;
  }

  /// Every photo filename referenced by a live tasting.
  ///
  /// This is the set the orphan sweep keeps; anything on disk and not in here
  /// belongs to a tasting that has been deleted.
  Set<String> referencedPhotos() => <String>{
    for (final tasting in tastings)
      if (tasting.photoName != null) tasting.photoName!,
  };
}
