/// The boundary between the screens and wherever the data actually lives.
library;

import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// Cleans up a name as typed, so no backend can store a ragged one.
///
/// Trims the ends and collapses runs of whitespace, so `"tom  kha "` and
/// `"tom kha"` are the same dish rather than two that look identical in the
/// list and sort apart.
///
/// A free function beside the interface rather than a step each caller
/// remembers: the two dialogs used to trim independently, neither collapsed
/// interior spaces, and a name arriving from an importer or another device
/// went through neither. Every implementation runs it, so the invariant holds
/// wherever a name comes from.
String cleanName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Everything the UI is allowed to do to the data.
///
/// Abstract for one reason that pays for itself immediately: widget tests run
/// against an in-memory fake, with no CRDT log, no file system and no clock.
///
/// There is deliberately only one real implementation and no plain-JSON
/// backend beside it. punchme has one because it *migrated* from a JSON file
/// to a CRDT log and still needs the old reader; this app was born synced, so
/// a second backend would be production-dead code whose only purpose is to be
/// tested.
///
/// Note the shape of the mutators: each one names an *intent* ("commit a
/// pick", "skip this dish") rather than taking a whole updated object. That is
/// what lets the CRDT implementation stamp exactly the fields the intent
/// touches. A generic `save(restaurant)` would have to write every field on
/// every call, and a rename would then clobber a pick committed on another
/// device — the field would carry a newer clock while holding an older value.
abstract class RaterRepository {
  /// Fires after every change, local or merged in from a peer. Carries no
  /// payload: listeners re-read [snapshot].
  Stream<void> get changes;

  /// The current state of everything.
  RaterSnapshot snapshot();

  /// Adds a restaurant and returns it.
  Future<void> addRestaurant({required String name, String? note});

  /// Renames a restaurant and/or replaces its note. Touches nothing else.
  Future<void> editRestaurant({
    required String id,
    required String name,
    String? note,
  });

  /// Tombstones a restaurant, its menu and its tastings.
  Future<void> deleteRestaurant(String id);

  /// Appends a dish to the end of a restaurant's menu.
  Future<void> addMenuItem({
    required String restaurantId,
    required String name,
    int? priceGrosz,
  });

  /// Edits a dish's name and price. Never touches its order or its skip.
  Future<void> editMenuItem({
    required String id,
    required String name,
    int? priceGrosz,
  });

  /// Tombstones a dish and its tastings.
  Future<void> deleteMenuItem(String id);

  /// Commits [menuItemId] as the dish to eat at [restaurantId].
  Future<void> commitPick({
    required String restaurantId,
    required String menuItemId,
  });

  /// Clears the committed pick at [restaurantId].
  Future<void> clearPick(String restaurantId);

  /// Passes over a dish: stamps its skip and clears the restaurant's pick.
  ///
  /// One call rather than two so the pair cannot half-apply — a skip that
  /// stamped the dish but left the pick committed would re-offer the same dish
  /// forever.
  Future<void> skipMenuItem({required String menuItemId, required DateTime at});

  /// Records a rating, clears the dish's skip, and clears the pick.
  Future<void> saveTasting(Tasting tasting);

  /// Tombstones a tasting.
  Future<void> deleteTasting(String id);

  /// Mints an id for a tasting about to be filled in.
  ///
  /// Needed before the rating screen opens, because the photo file is named
  /// after the tasting and the picture may be taken long before Save is
  /// pressed.
  String newTastingId();
}
