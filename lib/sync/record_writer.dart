/// The one way a record reaches the log, and the reads that inform it.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';

/// Merges every write into the record already stored, and decodes the reads
/// that a write needs first.
///
/// A class of its own rather than a handful of private methods on the
/// repository, so that "every write goes through [upsertMerged]" is a
/// structural fact instead of a convention the next method has to remember.
class RecordWriter {
  /// Writes to and reads from [store].
  const RecordWriter(this.store);

  /// The local CRDT log.
  final LogStore store;

  /// Writes [built]'s fields over the stored record's, keeping the rest.
  ///
  /// **Every write goes through here, and that is load-bearing.**
  /// `LogStore.upsert` *replaces* a record rather than merging into it —
  /// merging happens at sync time, not at write time — so handing it a record
  /// carrying only the fields one intent touches silently deletes every field
  /// it does not mention.
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
  Future<void> upsertMerged(Record built) async {
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

  /// Restamps a single field on an existing record, leaving the rest alone.
  ///
  /// A no-op when the record is absent: an intent aimed at something another
  /// device deleted has nothing to say, and inventing the record here would
  /// resurrect a tombstone.
  Future<void> writeField(String id, String field, Object? value) async {
    if (store.get(id) == null) return;
    await upsertMerged(
      Record(
        id: id,
        fields: <String, Field>{field: (value, store.nextHlc())},
      ),
    );
  }

  /// Writes only the pick field, so no other field's clock moves.
  Future<void> writePick(String restaurantId, String? menuItemId) => writeField(
    recordId(kRestaurantPrefix, restaurantId),
    kPendingField,
    menuItemId,
  );

  /// Writes only the skip field, for the same reason as [writePick].
  Future<void> writeSkip(String menuItemId, DateTime? at) => writeField(
    recordId(kMenuItemPrefix, menuItemId),
    kSkippedAtField,
    at?.toUtc().toIso8601String(),
  );

  /// The stored restaurant, or null when absent or tombstoned.
  Restaurant? restaurant(String id) =>
      _decode(kRestaurantPrefix, id, recordToRestaurant);

  /// The stored dish, or null when absent or tombstoned.
  MenuItem? menuItem(String id) =>
      _decode(kMenuItemPrefix, id, recordToMenuItem);

  T? _decode<T>(String prefix, String id, T? Function(Record) decoder) {
    final record = store.get(recordId(prefix, id));
    return record == null ? null : decoder(record);
  }
}
