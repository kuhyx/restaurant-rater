/// Model builders with sane defaults, so a test names only what it is about.
library;

import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// A fixed instant, so nothing in a test depends on the wall clock.
final DateTime kEpoch = DateTime.utc(2026, 8, 29, 12);

/// Builds a restaurant.
Restaurant aRestaurant({
  String id = 'r1',
  String name = 'Bar Tajski',
  String? note,
  String? pendingItemId,
  DateTime? createdAt,
}) => Restaurant(
  id: id,
  name: name,
  createdAt: createdAt ?? kEpoch,
  note: note,
  pendingItemId: pendingItemId,
);

/// Builds a menu item. [orderKey] defaults to the id, which sorts stably.
MenuItem aMenuItem({
  String id = 'm1',
  String restaurantId = 'r1',
  String name = 'tom kha z kurczakiem',
  String? orderKey,
  int? priceGrosz = 2400,
  DateTime? skippedAt,
}) => MenuItem(
  id: id,
  restaurantId: restaurantId,
  name: name,
  orderKey: orderKey ?? id,
  priceGrosz: priceGrosz,
  skippedAt: skippedAt,
);

/// Builds a tasting.
Tasting aTasting({
  String id = 't1',
  String menuItemId = 'm1',
  String restaurantId = 'r1',
  DateTime? eatenAt,
  int taste = 7,
  int smell = 6,
  int looks = 4,
  Macros macros = Macros.empty,
  String? photoName,
  String? note,
  int? priceGrosz,
}) => Tasting(
  id: id,
  menuItemId: menuItemId,
  restaurantId: restaurantId,
  eatenAt: eatenAt ?? kEpoch,
  taste: taste,
  smell: smell,
  looks: looks,
  macros: macros,
  photoName: photoName,
  note: note,
  priceGrosz: priceGrosz,
);
