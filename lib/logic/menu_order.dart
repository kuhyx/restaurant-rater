/// Ordering menu items, deterministically and identically on every device.
library;

import 'package:restaurant_rater/models/menu_item.dart';

/// Compares two dishes by menu position: the order they were entered.
///
/// `orderKey` is an HLC string, so a plain string comparison *is* chronological
/// order. The id breaks a tie, which is unreachable in practice (an HLC is
/// unique per device and carries the device id) but keeps the sort total, so
/// two devices holding the same dishes always list them the same way.
int byOrderKey(MenuItem a, MenuItem b) {
  final byKey = a.orderKey.compareTo(b.orderKey);
  return byKey != 0 ? byKey : a.id.compareTo(b.id);
}

/// Compares two skipped dishes: longest-ago skip first.
///
/// Used only once every remaining dish has been passed over, to decide which
/// to re-offer. A dish with no skip sorts first — it has waited longest by
/// definition, having never been refused at all.
int bySkippedAtThenOrder(MenuItem a, MenuItem b) {
  final left = a.skippedAt;
  final right = b.skippedAt;
  if (left == null && right != null) return -1;
  if (left != null && right == null) return 1;
  if (left != null && right != null) {
    final bySkip = left.compareTo(right);
    if (bySkip != 0) return bySkip;
  }
  return byOrderKey(a, b);
}

/// Returns [items] sorted into menu order.
List<MenuItem> sortedByOrderKey(Iterable<MenuItem> items) {
  final sorted = items.toList()..sort(byOrderKey);
  return sorted;
}
