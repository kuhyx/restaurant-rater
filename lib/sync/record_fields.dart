/// Field-level rules both record codecs obey.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:restaurant_rater/models/macros.dart';

/// The field holding energy, in kilocalories.
const String kKcalField = 'kcal';

/// The field holding protein, in grams.
const String kProteinField = 'proteinG';

/// The field holding fat, in grams.
const String kFatField = 'fatG';

/// The field holding carbohydrate, in grams.
const String kCarbsField = 'carbsG';

/// Writes [value] under [name] when present; writes an explicit null only on
/// an edit.
///
/// The distinction is the whole null-versus-omit discipline. On a create,
/// stamping null for every unfilled field would hand a peer that has not
/// merged yet a fresh clock carrying "nothing", which then beats real data.
/// On an edit, the null *is* the user's intent and has to win.
Map<String, Field> optionalField(
  String name,
  Object? value,
  Hlc at, {
  required bool includeCleared,
}) {
  if (value != null) return <String, Field>{name: (value, at)};
  if (includeCleared) return <String, Field>{name: (null, at)};
  return const <String, Field>{};
}

/// Flattens [macros] into four sibling fields stamped at [at].
///
/// Flattened rather than nested as a map, for two reasons. A `Record` field
/// value has to be a JSON scalar for the RTDB transport; and flat fields merge
/// independently, so correcting the protein on one device while correcting the
/// kcal on another keeps both corrections, where one nested blob would keep
/// whichever arrived later and silently drop the other.
///
/// Shared by the tasting and menu-item codecs so the two cannot drift into
/// spelling the same four numbers differently on the wire.
Map<String, Field> macrosToFields(
  Macros macros,
  Hlc at, {
  required bool includeCleared,
}) => <String, Field>{
  ...optionalField(kKcalField, macros.kcal, at, includeCleared: includeCleared),
  ...optionalField(
    kProteinField,
    macros.proteinG,
    at,
    includeCleared: includeCleared,
  ),
  ...optionalField(kFatField, macros.fatG, at, includeCleared: includeCleared),
  ...optionalField(
    kCarbsField,
    macros.carbsG,
    at,
    includeCleared: includeCleared,
  ),
};

/// Reads the four macro fields back out of [fields].
///
/// A component that is not a number reads as null — "unknown" — rather than
/// throwing: these records arrive from a peer that may be running a different
/// build, and one unreadable macro must not take down the whole record.
Macros macrosFromFields(Map<String, Field> fields) => Macros(
  kcal: _macro(fields[kKcalField]?.$1),
  proteinG: _macro(fields[kProteinField]?.$1),
  fatG: _macro(fields[kFatField]?.$1),
  carbsG: _macro(fields[kCarbsField]?.$1),
);

double? _macro(Object? value) => value is num ? value.toDouble() : null;
