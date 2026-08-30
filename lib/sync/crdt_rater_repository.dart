/// The repository, backed by the shared CRDT log.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/cascade_delete.dart';
import 'package:restaurant_rater/sync/log_queries.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
import 'package:restaurant_rater/sync/record_writer.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';
import 'package:uuid/uuid.dart';

/// Writes every change as CRDT records, so two devices converge.
///
/// Each method stamps only the fields its intent actually touches — see the
/// note on [RaterRepository] for why a generic "save the whole object" would
/// quietly lose a peer's concurrent edit.
class CrdtRaterRepository implements RaterRepository {
  /// Wraps [store].
  ///
  /// [uuid] and [now] are injected so a test can assert on exact ids and
  /// timestamps instead of matching patterns.
  ///
  /// Nothing here pushes to the network. The sync tick is driven from
  /// [LogStore.changes] in `sync_bootstrap.dart` instead, which fires after
  /// every mutation that reaches storage -- so a method added here later
  /// cannot forget to trigger a push, which a per-method `onWrite` callback
  /// makes very easy to do.
  CrdtRaterRepository({
    required this.store,
    this.uuid = const Uuid(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _write = RecordWriter(store);

  /// The local CRDT log this repository reads and writes.
  final LogStore store;

  /// Source of new record ids.
  final Uuid uuid;

  final DateTime Function() _now;

  /// The single seam every write passes through. See [RecordWriter].
  final RecordWriter _write;

  @override
  Stream<void> get changes => store.changes;

  @override
  RaterSnapshot snapshot() => snapshotOf(store.snapshot());

  @override
  String newTastingId() => uuid.v4();

  @override
  Future<void> addRestaurant({required String name, String? note}) async {
    final restaurant = Restaurant(
      id: uuid.v4(),
      name: cleanName(name),
      createdAt: _now().toUtc(),
      note: note,
    );
    await _write.upsertMerged(restaurantToRecord(restaurant, store.nextHlc()));
  }

  @override
  Future<void> editRestaurant({
    required String id,
    required String name,
    String? note,
  }) async {
    final existing = _write.restaurant(id);
    if (existing == null) return;
    // includeCleared: an edit that empties the note means it, and the explicit
    // null has to outrank the old value on every peer.
    await _write.upsertMerged(
      restaurantToRecord(
        existing.copyWith(name: cleanName(name), note: () => note),
        store.nextHlc(),
        includeCleared: true,
      ),
    );
  }

  @override
  Future<void> deleteRestaurant(String id) async {
    for (final recordId in idsToTombstoneForRestaurant(store.snapshot(), id)) {
      await store.delete(recordId);
    }
  }

  @override
  Future<void> addMenuItem({
    required String restaurantId,
    required String name,
    int? priceGrosz,
    Macros macros = Macros.empty,
  }) => _appendDish(
    restaurantId,
    (name: name, priceGrosz: priceGrosz, macros: macros),
  );

  /// Writes one dish onto the end of [restaurantId]'s menu.
  ///
  /// The menu position IS the clock this write is stamped at, so "the order I
  /// typed them in" needs no separate counter and cannot collide across
  /// devices. An import therefore has to await its dishes one at a time, in
  /// array order, for the keys to ascend the way the menu prints them.
  Future<void> _appendDish(String restaurantId, MenuDraft draft) async {
    final at = store.nextHlc();
    final item = MenuItem(
      id: uuid.v4(),
      restaurantId: restaurantId,
      name: cleanName(draft.name),
      orderKey: at.toStr(),
      priceGrosz: draft.priceGrosz,
      macros: draft.macros,
    );
    await _write.upsertMerged(menuItemToRecord(item, at));
  }

  @override
  Future<void> importMenu({
    required String restaurantName,
    required List<MenuDraft> dishes,
    String? restaurantNote,
    String? intoRestaurantId,
  }) async {
    var restaurantId = intoRestaurantId;
    if (restaurantId == null) {
      restaurantId = uuid.v4();
      await _write.upsertMerged(
        restaurantToRecord(
          Restaurant(
            id: restaurantId,
            name: cleanName(restaurantName),
            createdAt: _now().toUtc(),
            note: restaurantNote,
          ),
          store.nextHlc(),
        ),
      );
    } else if (_write.restaurant(restaurantId) == null) {
      // The target was deleted on another device between opening the import
      // screen and pressing the button. Writing the dishes anyway would leave
      // orphans that `snapshotOf` filters out and nobody could ever see.
      return;
    }
    for (final dish in dishes) {
      await _appendDish(restaurantId, dish);
    }
  }

  @override
  Future<void> editMenuItem({
    required String id,
    required String name,
    int? priceGrosz,
    Macros macros = Macros.empty,
  }) async {
    final existing = _write.menuItem(id);
    if (existing == null) return;
    await _write.upsertMerged(
      menuItemToRecord(
        existing.copyWith(
          name: cleanName(name),
          priceGrosz: () => priceGrosz,
          macros: macros,
        ),
        store.nextHlc(),
        includeCleared: true,
      ),
    );
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    for (final recordId in idsToTombstoneForMenuItem(store.snapshot(), id)) {
      await store.delete(recordId);
    }
  }

  @override
  Future<void> commitPick({
    required String restaurantId,
    required String menuItemId,
  }) => _write.writePick(restaurantId, menuItemId);

  @override
  Future<void> clearPick(String restaurantId) =>
      _write.writePick(restaurantId, null);

  @override
  Future<void> skipMenuItem({
    required String menuItemId,
    required DateTime at,
  }) async {
    final item = _write.menuItem(menuItemId);
    if (item == null) return;
    await _write.writeSkip(menuItemId, at);
    // Clearing the pick is half of what a skip means: leave it committed and
    // the sticky rule would hand back the very dish just refused.
    await _write.writePick(item.restaurantId, null);
  }

  @override
  Future<void> saveTasting(Tasting tasting) async {
    final isNew = store.get(recordId(kTastingPrefix, tasting.id)) == null;
    await _write.upsertMerged(
      tastingToRecord(tasting, store.nextHlc(), includeCleared: !isNew),
    );
    // A rated dish is no longer a skipped one; leaving the stamp would make it
    // sort oddly in round two for no reason the user could see.
    if (_write.menuItem(tasting.menuItemId)?.isSkipped ?? false) {
      await _write.writeSkip(tasting.menuItemId, null);
    }
    await _write.writePick(tasting.restaurantId, null);
  }

  @override
  Future<void> deleteTasting(String id) =>
      store.delete(recordId(kTastingPrefix, id));
}
