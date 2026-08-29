/// Optional macronutrients recorded alongside a tasting.
library;

import 'package:meta/meta.dart';

/// Returns the replacement value for one nullable field in a `copyWith`.
///
/// A bare `double? foo` parameter cannot distinguish *"set foo to null"* from
/// *"the caller did not mention foo"* — both arrive as null. Wrapping the
/// replacement in a callback makes the distinction structural: the parameter
/// itself being null means "unmentioned", and `() => null` means "clear it".
///
/// Deliberately not Flutter's `ValueGetter`, despite the identical shape: the
/// models are pure Dart and import no Flutter, and a same-named typedef would
/// collide the moment a widget file imported both.
///
/// It lives here, beside the model that uses it most, rather than in a file of
/// its own. A file containing nothing but a typedef has no executable lines,
/// so lcov emits no record for it at all and the coverage-completeness gate
/// reads it as an untested file -- indistinguishable from one that really is.
typedef Replace<T> = T Function();

/// Energy and the three macronutrients for one eaten portion.
///
/// Every field is nullable and every field is independent: these are typed in
/// by hand from a menu or a label, and a menu that prints kcal but not fat is
/// the normal case rather than an error. Nothing here is derived — in
/// particular kcal is *not* recomputed from the other three, because the two
/// disagree in practice and the printed figure is the one worth keeping.
///
/// Doubles throughout, never `num`: `jsonEncode(435)` and `jsonEncode(435.0)`
/// produce different text, which would make an unchanged value look like an
/// edit on every sync tick.
@immutable
class Macros {
  /// Creates a macro record. Omitted components stay null, meaning "unknown",
  /// which is a different claim from zero.
  const Macros({this.kcal, this.proteinG, this.fatG, this.carbsG});

  /// Rebuilds a record from [json], tolerating absent and wrongly-typed
  /// fields.
  ///
  /// A value that is not a number decodes to null rather than throwing: these
  /// records arrive from a peer device that may be running a different build,
  /// and one unreadable macro must not take down the whole dish.
  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
    kcal: _toDouble(json['kcal']),
    proteinG: _toDouble(json['proteinG']),
    fatG: _toDouble(json['fatG']),
    carbsG: _toDouble(json['carbsG']),
  );

  /// Nothing recorded. Distinct from all-zero, which claims a zero-calorie
  /// dish.
  static const Macros empty = Macros();

  /// Energy, in kilocalories.
  final double? kcal;

  /// Protein, in grams.
  final double? proteinG;

  /// Fat, in grams.
  final double? fatG;

  /// Carbohydrate, in grams.
  final double? carbsG;

  /// Whether no component was recorded at all.
  ///
  /// The UI uses this to skip the macros section entirely rather than render
  /// four empty rows.
  bool get isEmpty =>
      kcal == null && proteinG == null && fatG == null && carbsG == null;

  /// Whether at least one component was recorded.
  bool get isNotEmpty => !isEmpty;

  /// Returns a copy with the given components replaced.
  ///
  /// Each replacement is wrapped so that passing an explicit null clears the
  /// component; a bare `double?` parameter could not tell "clear this" from
  /// "leave it alone".
  Macros copyWith({
    Replace<double?>? kcal,
    Replace<double?>? proteinG,
    Replace<double?>? fatG,
    Replace<double?>? carbsG,
  }) => Macros(
    kcal: kcal == null ? this.kcal : kcal(),
    proteinG: proteinG == null ? this.proteinG : proteinG(),
    fatG: fatG == null ? this.fatG : fatG(),
    carbsG: carbsG == null ? this.carbsG : carbsG(),
  );

  /// Serializes to JSON, omitting unknown components.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (kcal != null) 'kcal': kcal,
    if (proteinG != null) 'proteinG': proteinG,
    if (fatG != null) 'fatG': fatG,
    if (carbsG != null) 'carbsG': carbsG,
  };

  static double? _toDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  @override
  String toString() =>
      'Macros(kcal: $kcal, proteinG: $proteinG, '
      'fatG: $fatG, carbsG: $carbsG)';

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.fatG == fatG &&
      other.carbsG == carbsG;

  @override
  int get hashCode => Object.hash(kcal, proteinG, fatG, carbsG);
}
