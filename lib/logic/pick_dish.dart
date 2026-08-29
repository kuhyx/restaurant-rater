/// Choosing which dish to eat next. Pure: no clock, no IO, no randomness.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/logic/menu_order.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// Why the pick landed on the dish it did.
///
/// Carried out to the UI so the screen can explain itself — "next on the menu"
/// and "everything's been tried, so here's the one you've gone longest
/// without" are very different messages to be given at a table.
enum PickReason {
  /// The menu is empty; there is nothing to pick.
  emptyMenu,

  /// A dish was already committed and is being honoured.
  sticky,

  /// The next unrated dish in menu order.
  nextUnrated,

  /// Every unrated dish has been skipped, so the longest-ago skip comes back.
  skippedFallback,

  /// The whole menu has been rated; this is the longest since last eaten.
  roundTwo,
}

/// The dish to eat next, and why.
@immutable
class PickResult {
  /// Creates a pick result.
  const PickResult({required this.item, required this.reason});

  /// The chosen dish, or null exactly when [reason] is [PickReason.emptyMenu].
  final MenuItem? item;

  /// Why this dish.
  final PickReason reason;

  @override
  String toString() => 'PickResult(${item?.name}, $reason)';
}

/// Picks the dish to eat next at [restaurant].
///
/// [menu] is that restaurant's live dishes and [tastings] its live tastings;
/// both are already filtered of tombstones by the repository.
///
/// The rules, in order:
///
/// 1. Nothing on the menu -> [PickReason.emptyMenu].
/// 2. **Sticky.** A committed pick that still exists is returned unchanged.
/// 3. The lowest-ordered unrated dish that has not been skipped.
/// 4. If every unrated dish has been skipped, the one skipped longest ago.
/// 5. If everything is rated, the dish last eaten longest ago.
///
/// Note what rule 2 does *not* check: whether the committed dish is unrated.
/// A round-two pick is by definition already rated, so requiring unrated here
/// would reject the app's own suggestion on the very next tap and bounce
/// straight back to rule 5. Unratedness selects *candidates* in rules 3 and 4;
/// it has no business overriding a decision already committed.
///
/// A committed id naming a dish that no longer exists (deleted here, or a
/// delete merged in from another device) is treated as absent, so a stale
/// pick self-heals rather than wedging the screen.
PickResult pickNext({
  required Restaurant restaurant,
  required List<MenuItem> menu,
  required List<Tasting> tastings,
}) {
  if (menu.isEmpty) {
    return const PickResult(item: null, reason: PickReason.emptyMenu);
  }

  final pendingId = restaurant.pendingItemId;
  if (pendingId != null) {
    for (final item in menu) {
      if (item.id == pendingId) {
        return PickResult(item: item, reason: PickReason.sticky);
      }
    }
  }

  final ratedIds = <String>{for (final tasting in tastings) tasting.menuItemId};
  final unrated = menu.where((item) => !ratedIds.contains(item.id)).toList();

  if (unrated.isEmpty) {
    return PickResult(
      item: _longestSinceEaten(menu, tastings),
      reason: PickReason.roundTwo,
    );
  }

  final fresh = unrated.where((item) => !item.isSkipped).toList();
  if (fresh.isNotEmpty) {
    fresh.sort(byOrderKey);
    return PickResult(item: fresh.first, reason: PickReason.nextUnrated);
  }

  unrated.sort(bySkippedAtThenOrder);
  return PickResult(item: unrated.first, reason: PickReason.skippedFallback);
}

/// Whether skipping would actually offer a different dish.
///
/// False when one unrated dish is left: skipping it would clear the pick,
/// re-run the rules and land on the very same dish. The UI disables Skip and
/// says so, rather than animating a change that did not happen — a button that
/// visibly does nothing reads as a bug.
bool canSkipToAnother({
  required List<MenuItem> menu,
  required List<Tasting> tastings,
}) {
  final ratedIds = <String>{for (final tasting in tastings) tasting.menuItemId};
  final unratedCount = menu.where((item) => !ratedIds.contains(item.id)).length;
  // Round two: every dish is a candidate again, so a skip moves on as long as
  // there is more than one dish at all.
  if (unratedCount == 0) return menu.length > 1;
  return unratedCount > 1;
}

/// The dish whose most recent tasting is oldest.
///
/// Only reached when every dish has been rated, so every dish has at least one
/// tasting; the null guard is for a merge that dropped one, and sorts such a
/// dish first because "no record of eating it" is the longest wait there is.
MenuItem _longestSinceEaten(List<MenuItem> menu, List<Tasting> tastings) {
  final lastEaten = <String, DateTime>{};
  for (final tasting in tastings) {
    final previous = lastEaten[tasting.menuItemId];
    if (previous == null || tasting.eatenAt.isAfter(previous)) {
      lastEaten[tasting.menuItemId] = tasting.eatenAt;
    }
  }
  final ordered = menu.toList()
    ..sort((a, b) {
      final left = lastEaten[a.id];
      final right = lastEaten[b.id];
      if (left == null && right != null) return -1;
      if (left != null && right == null) return 1;
      if (left != null && right != null) {
        final byDate = left.compareTo(right);
        if (byDate != 0) return byDate;
      }
      return byOrderKey(a, b);
    });
  return ordered.first;
}

/// The worst-scoring dish on [menu], for a "try it again?" prompt.
///
/// Null when nothing has been rated. Unrated dishes are never returned: they
/// have no score to be worst.
MenuItem? lowestScoring({
  required List<MenuItem> menu,
  required List<Tasting> tastings,
}) {
  MenuItem? worst;
  var worstScore = double.infinity;
  for (final item in menu) {
    final score = meanOverall(
      tastings.where((tasting) => tasting.menuItemId == item.id),
    );
    if (score == null) continue;
    if (score < worstScore ||
        (score == worstScore && worst != null && byOrderKey(item, worst) < 0)) {
      worst = item;
      worstScore = score;
    }
  }
  return worst;
}
