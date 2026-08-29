/// Working out everything a delete has to take with it. Pure.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';

/// Record ids to tombstone when restaurant [restaurantId] is deleted.
///
/// The restaurant, every dish on its menu, and every tasting of those dishes.
/// Without the cascade the children survive as records nothing can reach: no
/// screen lists them, so nothing can delete them, and every future sync keeps
/// pushing them to every device forever.
///
/// Pure and returning ids rather than doing the deleting, so the fan-out is
/// testable against a plain map with no store, no clock and no IO.
List<String> idsToTombstoneForRestaurant(Log log, String restaurantId) {
  final ids = <String>[recordId(kRestaurantPrefix, restaurantId)];
  final doomedItems = <String>{};

  for (final record in log.values) {
    if (record.deleted) continue;
    if (bareId(record.id, kMenuItemPrefix) == null) continue;
    if (record.fields[kRestaurantField]?.$1 != restaurantId) continue;
    ids.add(record.id);
    doomedItems.add(bareId(record.id, kMenuItemPrefix)!);
  }

  for (final record in log.values) {
    if (record.deleted) continue;
    if (bareId(record.id, kTastingPrefix) == null) continue;
    final owner = record.fields[kMenuItemField]?.$1;
    // Matched through the menu item, not the tasting's denormalised
    // `restaurant` field: that field is a cache and can be stale, and a stale
    // cache here would strand a tasting instead of deleting it.
    if (owner is String && doomedItems.contains(owner)) ids.add(record.id);
  }

  return ids;
}

/// Record ids to tombstone when menu item [menuItemId] is deleted.
///
/// The dish and every tasting of it. A tasting whose dish is gone has nothing
/// to name in the history — it would render as a rating of a blank.
List<String> idsToTombstoneForMenuItem(Log log, String menuItemId) {
  final ids = <String>[recordId(kMenuItemPrefix, menuItemId)];
  for (final record in log.values) {
    if (record.deleted) continue;
    if (bareId(record.id, kTastingPrefix) == null) continue;
    if (record.fields[kMenuItemField]?.$1 == menuItemId) ids.add(record.id);
  }
  return ids;
}
