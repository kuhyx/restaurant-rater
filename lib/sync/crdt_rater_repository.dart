/// The repository, backed by the shared CRDT log.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/cascade_delete.dart';
import 'package:restaurant_rater/sync/log_queries.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
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
  }) : _now = now ?? DateTime.now;

  /// The local CRDT log this repository reads and writes.
  final LogStore store;

  /// Source of new record ids.
  final Uuid uuid;

  final DateTime Function() _now;

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
      name: name,
      createdAt: _now().toUtc(),
      note: note,
    );
    await _upsertMerged(restaurantToRecord(restaurant, store.nextHlc()));
  }

  @override
  Future<void> editRestaurant({
    required String id,
    required String name,
    String? note,
  }) async {
    final existing = _restaurant(id);
    if (existing == null) return;
    // includeCleared: an edit that empties the note means it, and the explicit
    // null has to outrank the old value on every peer.
    await _upsertMerged(
      restaurantToRecord(
        existing.copyWith(name: name, note: () => note),
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
  }) async {
    final at = store.nextHlc();
    final item = MenuItem(
      id: uuid.v4(),
      restaurantId: restaurantId,
      name: name,
      // The menu position IS the clock this write is stamped at, so "the order
      // I typed them in" needs no separate counter and cannot collide across
      // devices.
      orderKey: at.toStr(),
      priceGrosz: priceGrosz,
    );
    await _upsertMerged(menuItemToRecord(item, at));
  }

  @override
  Future<void> editMenuItem({
    required String id,
    required String name,
    int? priceGrosz,
  }) async {
    final existing = _menuItem(id);
    if (existing == null) return;
    await _upsertMerged(
      menuItemToRecord(
        existing.copyWith(name: name, priceGrosz: () => priceGrosz),
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
  }) => _writePick(restaurantId, menuItemId);

  @override
  Future<void> clearPick(String restaurantId) => _writePick(restaurantId, null);

  @override
  Future<void> skipMenuItem({
    required String menuItemId,
    required DateTime at,
  }) async {
    final item = _menuItem(menuItemId);
    if (item == null) return;
    await _writeSkip(menuItemId, at);
    // Clearing the pick is half of what a skip means: leave it committed and
    // the sticky rule would hand back the very dish just refused.
    await _writePick(item.restaurantId, null);
  }

  @override
  Future<void> saveTasting(Tasting tasting) async {
    final isNew = store.get(recordId(kTastingPrefix, tasting.id)) == null;
    await _upsertMerged(
      tastingToRecord(tasting, store.nextHlc(), includeCleared: !isNew),
    );
    // A rated dish is no longer a skipped one; leaving the stamp would make it
    // sort oddly in round two for no reason the user could see.
    if (_menuItem(tasting.menuItemId)?.isSkipped ?? false) {
      await _writeSkip(tasting.menuItemId, null);
    }
    await _writePick(tasting.restaurantId, null);
  }

  @override
  Future<void> deleteTasting(String id) =>
      store.delete(recordId(kTastingPrefix, id));

  /// Writes only the pick field, so no other field's clock moves.
  Future<void> _writePick(String restaurantId, String? menuItemId) =>
      _writeField(
        recordId(kRestaurantPrefix, restaurantId),
        kPendingField,
        menuItemId,
      );

  /// Writes only the skip field, for the same reason as [_writePick].
  Future<void> _writeSkip(String menuItemId, DateTime? at) => _writeField(
    recordId(kMenuItemPrefix, menuItemId),
    kSkippedAtField,
    at?.toUtc().toIso8601String(),
  );

  /// Restamps a single field on an existing record, leaving the rest alone.
  Future<void> _writeField(String id, String field, Object? value) async {
    if (store.get(id) == null) return;
    await _upsertMerged(
      Record(
        id: id,
        fields: <String, Field>{field: (value, store.nextHlc())},
      ),
    );
  }

  /// Writes [built]'s fields over the stored record's, keeping the rest.
  ///
  /// **Every write in this class goes through here, and that is
  /// load-bearing.** `LogStore.upsert` *replaces* a record rather than merging
  /// into it — merging happens at sync time, not at write time — so handing it
  /// a record carrying only the fields one intent touches silently deletes
  /// every field it does not mention.
  ///
  /// That is not a theoretical hazard. The first build on the phone lost each
  /// restaurant's name the instant the pick screen committed a pick, because
  /// the pick write named only `pending`; the list went straight to
  /// "Restaurant is gone". The same shape was waiting in `editRestaurant`
  /// (whose codec omits `pending`) and `editMenuItem` (which omits
  /// `skippedAt`) — renaming a dish would have erased its skip.
  ///
  /// Carrying the untouched fields forward at their *original* clocks is what
  /// keeps the intent honest: they have not changed, so they must not outrank
  /// a peer's concurrent edit to them. Only the fields [built] names get a new
  /// clock.
  Future<void> _upsertMerged(Record built) async {
    final existing = store.get(built.id);
    await store.upsert(
      existing == null
          ? built
          : Record(
              id: built.id,
              fields: <String, Field>{...existing.fields, ...built.fields},
              deleted: existing.deleted,
              deletedHlc: existing.deletedHlc,
            ),
    );
  }

  /// The stored restaurant, or null when absent or tombstoned.
  Restaurant? _restaurant(String id) =>
      _decode(kRestaurantPrefix, id, recordToRestaurant);

  /// The stored dish, or null when absent or tombstoned.
  MenuItem? _menuItem(String id) =>
      _decode(kMenuItemPrefix, id, recordToMenuItem);

  T? _decode<T>(String prefix, String id, T? Function(Record) decoder) {
    final record = store.get(recordId(prefix, id));
    return record == null ? null : decoder(record);
  }
}
