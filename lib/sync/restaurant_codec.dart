/// Translating a restaurant to and from the shared CRDT record shape.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/sync/record_ids.dart';

/// The field holding the restaurant's name.
const String kNameField = 'name';

/// The field holding the free-text note.
const String kNoteField = 'note';

/// The field holding the creation instant, as an ISO-8601 UTC string.
const String kCreatedAtField = 'createdAt';

/// The field holding the committed pick's menu item id.
const String kPendingField = 'pending';

/// Builds a record for [restaurant], stamping the editable fields at [at].
///
/// **This never writes [kPendingField], and that omission is load-bearing.**
/// Only `commitPick` and `clearPick` touch the pick. If a rename wrote it too,
/// renaming a place on the phone would stamp the pick with a fresh clock while
/// carrying whatever value the phone last saw — and under last-writer-wins
/// that stale value would beat a pick genuinely committed on another device a
/// moment earlier. Keeping the field out of the general encoder makes that
/// class of bug unreachable rather than merely unlikely.
///
/// [includeCleared] distinguishes a create from an edit. On create there is
/// nothing on any peer to lose, so an absent note is simply omitted. On edit,
/// clearing the note is deliberate and must beat the old value, so it is
/// written as an explicit null.
Record restaurantToRecord(
  Restaurant restaurant,
  Hlc at, {
  bool includeCleared = false,
}) => Record(
  id: recordId(kRestaurantPrefix, restaurant.id),
  fields: <String, Field>{
    kNameField: (restaurant.name, at),
    kCreatedAtField: (restaurant.createdAt.toUtc().toIso8601String(), at),
    if (restaurant.note != null)
      kNoteField: (restaurant.note, at)
    else if (includeCleared)
      kNoteField: (null, at),
  },
);

/// Rebuilds a restaurant from [record], or null when it does not describe one.
///
/// Null rather than a throw for a tombstone, a record of another kind, or one
/// written by a newer build with a field this one cannot read: a single
/// unreadable record must not take down the whole load. A restaurant with no
/// readable name is not a restaurant.
Restaurant? recordToRestaurant(Record record) {
  if (record.deleted) return null;
  final id = bareId(record.id, kRestaurantPrefix);
  if (id == null) return null;

  final name = record.fields[kNameField]?.$1;
  if (name is! String) return null;

  final createdAt = _parseDate(record.fields[kCreatedAtField]?.$1);
  final note = record.fields[kNoteField]?.$1;
  final pending = record.fields[kPendingField]?.$1;

  return Restaurant(
    id: id,
    name: name,
    // A record from a build that predates the field still loads; the epoch is
    // a stable sort position, not a claim about when it was added.
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    note: note is String && note.isNotEmpty ? note : null,
    pendingItemId: pending is String && pending.isNotEmpty ? pending : null,
  );
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
