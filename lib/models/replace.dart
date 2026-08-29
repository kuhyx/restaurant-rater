/// The `copyWith` helper that can tell "clear this field" from "leave it".
library;

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
typedef Replace<T> = T Function();
