/// One occasion of eating and rating a dish.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/replace.dart';

/// The lowest score on each axis.
const int kMinScore = 0;

/// The highest score on each axis.
///
/// Ten, not five: this is the scale the notes were already written on
/// (`smak - 7/10`), and rescaling old judgements is how they stop being
/// comparable to new ones.
const int kMaxScore = 10;

/// A rating of one dish, on one occasion.
///
/// A dish may be tasted many times — the model is append-only, so re-ordering
/// a dish months later adds a row rather than overwriting the first verdict.
/// "Rated" therefore means "has at least one tasting".
@immutable
class Tasting {
  /// Creates a tasting.
  const Tasting({
    required this.id,
    required this.menuItemId,
    required this.restaurantId,
    required this.eatenAt,
    required this.taste,
    required this.smell,
    required this.looks,
    this.macros = Macros.empty,
    this.photoName,
    this.note,
    this.priceGrosz,
  });

  /// Stable identity, a uuid v4.
  ///
  /// Generated when the rating screen opens, before a photo can be taken, so
  /// the photo file can be named after it with no later rename step.
  final String id;

  /// The dish this rates. The authoritative link: every join goes through it.
  final String menuItemId;

  /// The restaurant, denormalised so per-restaurant views need no join.
  ///
  /// A cache, not a source of truth — use it to narrow a list, then confirm
  /// through [menuItemId], which is the field that cannot go stale.
  final String restaurantId;

  /// When it was eaten.
  final DateTime eatenAt;

  /// Smak, 0-10.
  final int taste;

  /// Zapach, 0-10.
  final int smell;

  /// Estetyka, 0-10.
  final int looks;

  /// Optional macronutrients for this portion.
  final Macros macros;

  /// The photo's bare filename, e.g. `<id>.jpg`, or null if none was taken.
  ///
  /// A filename, never a path: an absolute path is meaningless on another
  /// device and changes across a reinstall. The bytes stay on the device that
  /// took them — only this name syncs.
  final String? photoName;

  /// Free text: "too salty", "portion tiny".
  final String? note;

  /// What was actually paid, in grosz, when it differed from the menu price.
  final int? priceGrosz;

  /// Returns a copy with the given fields replaced.
  Tasting copyWith({
    DateTime? eatenAt,
    int? taste,
    int? smell,
    int? looks,
    Macros? macros,
    Replace<String?>? photoName,
    Replace<String?>? note,
    Replace<int?>? priceGrosz,
  }) => Tasting(
    id: id,
    menuItemId: menuItemId,
    restaurantId: restaurantId,
    eatenAt: eatenAt ?? this.eatenAt,
    taste: taste ?? this.taste,
    smell: smell ?? this.smell,
    looks: looks ?? this.looks,
    macros: macros ?? this.macros,
    photoName: photoName == null ? this.photoName : photoName(),
    note: note == null ? this.note : note(),
    priceGrosz: priceGrosz == null ? this.priceGrosz : priceGrosz(),
  );

  @override
  String toString() => 'Tasting($id, $menuItemId, $taste/$smell/$looks)';

  @override
  bool operator ==(Object other) =>
      other is Tasting &&
      other.id == id &&
      other.menuItemId == menuItemId &&
      other.restaurantId == restaurantId &&
      other.eatenAt == eatenAt &&
      other.taste == taste &&
      other.smell == smell &&
      other.looks == looks &&
      other.macros == macros &&
      other.photoName == photoName &&
      other.note == note &&
      other.priceGrosz == priceGrosz;

  @override
  int get hashCode => Object.hash(
    id,
    menuItemId,
    restaurantId,
    eatenAt,
    taste,
    smell,
    looks,
    macros,
    photoName,
    note,
    priceGrosz,
  );
}
