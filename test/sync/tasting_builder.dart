/// A tasting bound to ids minted by a live repository.
library;

import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// Builds a tasting of [menuItemId] with a fresh id from [repository].
Tasting aTastingOf(
  RaterRepository repository,
  String restaurantId,
  String menuItemId, {
  int taste = 7,
  int smell = 6,
  int looks = 4,
  DateTime? eatenAt,
}) => Tasting(
  id: repository.newTastingId(),
  menuItemId: menuItemId,
  restaurantId: restaurantId,
  eatenAt: eatenAt ?? DateTime.utc(2026, 8, 29, 12),
  taste: taste,
  smell: smell,
  looks: looks,
);
