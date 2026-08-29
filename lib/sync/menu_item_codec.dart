/// Translating a menu item to and from the shared CRDT record shape.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/sync/record_ids.dart';

/// The field holding the owning restaurant's bare id.
const String kRestaurantField = 'restaurant';

/// The field holding the dish name.
const String kItemNameField = 'name';

/// The field holding the price, in grosz.
const String kPriceField = 'priceGrosz';

/// The field holding the menu-position key.
const String kOrderKeyField = 'orderKey';

/// The field holding the last skip instant.
const String kSkippedAtField = 'skippedAt';

/// Builds a record for [item], stamping the editable fields at [at].
///
/// **This never writes [kSkippedAtField]**, for the same reason
/// `restaurantToRecord` never writes the pick: only `skipMenuItem` and the
/// clear that follows a rating own that field. Correcting a typo in a dish
/// name must not be able to resurrect or erase a skip recorded elsewhere.
///
/// [kOrderKeyField] *is* written, but the value passed in is the one the item
/// was created with — it is never recomputed, so a rename cannot reorder the
/// menu.
Record menuItemToRecord(
  MenuItem item,
  Hlc at, {
  bool includeCleared = false,
}) => Record(
  id: recordId(kMenuItemPrefix, item.id),
  fields: <String, Field>{
    kRestaurantField: (item.restaurantId, at),
    kItemNameField: (item.name, at),
    kOrderKeyField: (item.orderKey, at),
    if (item.priceGrosz != null)
      kPriceField: (item.priceGrosz, at)
    else if (includeCleared)
      kPriceField: (null, at),
  },
);

/// Rebuilds a menu item from [record], or null when it does not describe one.
///
/// A dish needs an id, a restaurant and a name to exist at all; anything else
/// missing is survivable. A record with no `orderKey` — written by a build
/// that predates the field — falls back to its own record id, which is stable
/// and unique, so such a dish keeps a fixed (if arbitrary) menu position
/// rather than jumping around on every load.
MenuItem? recordToMenuItem(Record record) {
  if (record.deleted) return null;
  final id = bareId(record.id, kMenuItemPrefix);
  if (id == null) return null;

  final restaurantId = record.fields[kRestaurantField]?.$1;
  final name = record.fields[kItemNameField]?.$1;
  if (restaurantId is! String || name is! String) return null;

  final orderKey = record.fields[kOrderKeyField]?.$1;
  final price = record.fields[kPriceField]?.$1;
  final skippedAt = record.fields[kSkippedAtField]?.$1;

  return MenuItem(
    id: id,
    restaurantId: restaurantId,
    name: name,
    orderKey: orderKey is String && orderKey.isNotEmpty ? orderKey : id,
    // `is int` rather than `is num`: a price is grosz and must never arrive as
    // a double, which is exactly the drift this catches instead of rounding.
    priceGrosz: price is int ? price : null,
    skippedAt: skippedAt is String
        ? DateTime.tryParse(skippedAt)?.toUtc()
        : null,
  );
}
