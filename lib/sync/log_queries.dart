/// Reading a whole CRDT log into one consistent domain snapshot.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';

/// Decodes [log] into a snapshot, dropping tombstones and orphans.
///
/// The orphan filters are defence in depth, not the primary mechanism:
/// deleting a restaurant cascades tombstones onto its dishes and their
/// tastings. But a cascade written by an older build, or interrupted midway,
/// would otherwise leave dishes belonging to a restaurant that no longer
/// exists — visible in the history and impossible to delete, because the only
/// screen that could reach them is gone. Filtering here means such a record is
/// merely inert rather than a ghost in the UI.
RaterSnapshot snapshotOf(Log log) {
  final restaurants = <Restaurant>[];
  final menuItems = <MenuItem>[];
  final tastings = <Tasting>[];

  for (final record in log.values) {
    final restaurant = recordToRestaurant(record);
    if (restaurant != null) {
      restaurants.add(restaurant);
      continue;
    }
    final item = recordToMenuItem(record);
    if (item != null) {
      menuItems.add(item);
      continue;
    }
    final tasting = recordToTasting(record);
    if (tasting != null) tastings.add(tasting);
  }

  final liveRestaurants = <String>{for (final r in restaurants) r.id};
  final liveItems = <MenuItem>[
    for (final item in menuItems)
      if (liveRestaurants.contains(item.restaurantId)) item,
  ];
  final liveItemIds = <String>{for (final item in liveItems) item.id};

  restaurants.sort(_byNameThenId);
  return RaterSnapshot(
    restaurants: restaurants,
    menuItems: liveItems,
    tastings: <Tasting>[
      for (final tasting in tastings)
        if (liveItemIds.contains(tasting.menuItemId)) tasting,
    ],
  );
}

/// Orders restaurants for the list: alphabetical, id breaking ties.
///
/// Case-insensitive, so `bar Tajski` and `Bar Tajski` sit together rather than
/// in two separate runs of the alphabet.
int _byNameThenId(Restaurant a, Restaurant b) {
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
