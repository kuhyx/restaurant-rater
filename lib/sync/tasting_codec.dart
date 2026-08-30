/// Translating a tasting to and from the shared CRDT record shape.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/record_fields.dart';
import 'package:restaurant_rater/sync/record_ids.dart';

/// The field holding the rated dish's bare id.
const String kMenuItemField = 'menuItem';

/// The field holding the restaurant's bare id (denormalised).
const String kTastingRestaurantField = 'restaurant';

/// The field holding when it was eaten.
const String kEatenAtField = 'eatenAt';

/// The field holding smak, 0-10.
const String kTasteField = 'taste';

/// The field holding zapach, 0-10.
const String kSmellField = 'smell';

/// The field holding estetyka, 0-10.
const String kLooksField = 'looks';

/// The field holding the photo's bare filename.
const String kPhotoField = 'photo';

/// The field holding the free-text note.
const String kTastingNoteField = 'note';

/// The field holding the price paid, in grosz.
const String kTastingPriceField = 'priceGrosz';

/// Builds a record for [tasting], stamping every field at [at].
///
/// Macros are flattened into four sibling fields by [macrosToFields]; see
/// there for why they are not nested.
Record tastingToRecord(
  Tasting tasting,
  Hlc at, {
  bool includeCleared = false,
}) => Record(
  id: recordId(kTastingPrefix, tasting.id),
  fields: <String, Field>{
    kMenuItemField: (tasting.menuItemId, at),
    kTastingRestaurantField: (tasting.restaurantId, at),
    kEatenAtField: (tasting.eatenAt.toUtc().toIso8601String(), at),
    kTasteField: (tasting.taste, at),
    kSmellField: (tasting.smell, at),
    kLooksField: (tasting.looks, at),
    ...macrosToFields(
      tasting.macros,
      at,
      includeCleared: includeCleared,
    ),
    ...optionalField(
      kPhotoField,
      tasting.photoName,
      at,
      includeCleared: includeCleared,
    ),
    ...optionalField(
      kTastingNoteField,
      tasting.note,
      at,
      includeCleared: includeCleared,
    ),
    ...optionalField(
      kTastingPriceField,
      tasting.priceGrosz,
      at,
      includeCleared: includeCleared,
    ),
  },
);

/// Rebuilds a tasting from [record], or null when it does not describe one.
///
/// The three scores default to 0 when unreadable rather than rejecting the
/// record: a rating that lost one axis in a merge is still worth keeping, and
/// dropping it would silently delete a meal from the history.
Tasting? recordToTasting(Record record) {
  if (record.deleted) return null;
  final id = bareId(record.id, kTastingPrefix);
  if (id == null) return null;

  final menuItemId = record.fields[kMenuItemField]?.$1;
  final restaurantId = record.fields[kTastingRestaurantField]?.$1;
  if (menuItemId is! String || restaurantId is! String) return null;

  final eatenAt = record.fields[kEatenAtField]?.$1;
  final photo = record.fields[kPhotoField]?.$1;
  final note = record.fields[kTastingNoteField]?.$1;
  final price = record.fields[kTastingPriceField]?.$1;

  return Tasting(
    id: id,
    menuItemId: menuItemId,
    restaurantId: restaurantId,
    eatenAt:
        (eatenAt is String ? DateTime.tryParse(eatenAt)?.toUtc() : null) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    taste: _score(record.fields[kTasteField]?.$1),
    smell: _score(record.fields[kSmellField]?.$1),
    looks: _score(record.fields[kLooksField]?.$1),
    macros: macrosFromFields(record.fields),
    photoName: photo is String && photo.isNotEmpty ? photo : null,
    note: note is String && note.isNotEmpty ? note : null,
    priceGrosz: price is int ? price : null,
  );
}

int _score(Object? value) =>
    value is int ? value.clamp(kMinScore, kMaxScore) : 0;
