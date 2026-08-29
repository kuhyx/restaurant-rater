/// One dish on a restaurant's menu.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/models/macros.dart';

/// A dish: its name, what it costs, where it sits in the menu, and whether it
/// has been passed over.
@immutable
class MenuItem {
  /// Creates a menu item.
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.orderKey,
    this.priceGrosz,
    this.skippedAt,
  });

  /// Stable identity, a uuid v4.
  final String id;

  /// The owning restaurant's id, stored bare (no `r:` record prefix).
  final String restaurantId;

  /// The dish, as printed: `tom kha z kurczakiem`.
  final String name;

  /// Where this dish sits in the menu — the sort key for "the order I typed
  /// them in", and the whole basis of the menu-order pick rule.
  ///
  /// This is an `Hlc.toStr()` taken from the sync clock at creation and never
  /// rewritten. That format is lexicographically sortable and globally unique,
  /// with the device id as the final tie-break.
  ///
  /// An integer index would fail two ways that this does not: two devices
  /// adding a dish offline would both compute the same index and one would
  /// have to lose, and deleting a dish would force a renumbering write on
  /// every dish after it — N racing writes to fix an ordering that never
  /// needed to move.
  final String orderKey;

  /// Price in grosz, or null when it was not recorded.
  ///
  /// An integer, never a double: 24.10 has no exact binary representation, so
  /// a price stored as a double round-trips through JSON as 24.099999999999998
  /// and starts reading as an edit on every sync tick.
  final int? priceGrosz;

  /// When this dish was last passed over, or null if it never was.
  ///
  /// A timestamp rather than a skip *counter*, because the log merges
  /// last-writer-wins: two devices concurrently incrementing a counter would
  /// converge on 1 rather than 2, silently losing a skip. A timestamp merges
  /// correctly and says more — ordering by it re-offers the longest-ago
  /// skipped dish first, which is what you want once the menu runs low.
  ///
  /// Cleared when the dish is finally rated.
  final DateTime? skippedAt;

  /// Whether this dish has been passed over at least once.
  bool get isSkipped => skippedAt != null;

  /// Returns a copy with the given fields replaced.
  MenuItem copyWith({
    String? name,
    String? orderKey,
    Replace<int?>? priceGrosz,
    Replace<DateTime?>? skippedAt,
  }) => MenuItem(
    id: id,
    restaurantId: restaurantId,
    name: name ?? this.name,
    orderKey: orderKey ?? this.orderKey,
    priceGrosz: priceGrosz == null ? this.priceGrosz : priceGrosz(),
    skippedAt: skippedAt == null ? this.skippedAt : skippedAt(),
  );

  @override
  String toString() => 'MenuItem($id, $name)';

  @override
  bool operator ==(Object other) =>
      other is MenuItem &&
      other.id == id &&
      other.restaurantId == restaurantId &&
      other.name == name &&
      other.orderKey == orderKey &&
      other.priceGrosz == priceGrosz &&
      other.skippedAt == skippedAt;

  @override
  int get hashCode =>
      Object.hash(id, restaurantId, name, orderKey, priceGrosz, skippedAt);
}
