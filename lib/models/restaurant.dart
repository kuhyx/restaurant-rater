/// A place with a menu.
library;

import 'package:meta/meta.dart';
import 'package:restaurant_rater/models/macros.dart';

/// A restaurant, and the dish currently committed to be eaten there.
@immutable
class Restaurant {
  /// Creates a restaurant.
  const Restaurant({
    required this.id,
    required this.name,
    required this.createdAt,
    this.note,
    this.pendingItemId,
  });

  /// Stable identity, a uuid v4. Survives renames, so the ratings stay
  /// attached when a place turns out to have been typed in wrong.
  final String id;

  /// What it is called.
  final String name;

  /// When it was added. Only used for a stable fallback ordering of the list.
  final DateTime createdAt;

  /// Free text: an address, a district, "the one by the tram stop".
  final String? note;

  /// The committed pick — the menu item this restaurant is currently offering.
  ///
  /// This is the whole reason the pick survives a force-stop: it is persisted
  /// state on the restaurant, not a value recomputed per tap. It is cleared
  /// when the dish is rated or skipped, and treated as absent when it names an
  /// item that no longer exists (a delete merged in from another device), so a
  /// stale id self-heals instead of wedging the pick screen.
  final String? pendingItemId;

  /// Returns a copy with the given fields replaced.
  ///
  /// [note] and [pendingItemId] take a callback so an explicit clear is
  /// distinguishable from an omission — clearing the pick is exactly what
  /// rating a dish does, and it must not be confused with leaving it alone.
  Restaurant copyWith({
    String? name,
    DateTime? createdAt,
    Replace<String?>? note,
    Replace<String?>? pendingItemId,
  }) => Restaurant(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    note: note == null ? this.note : note(),
    pendingItemId: pendingItemId == null ? this.pendingItemId : pendingItemId(),
  );

  @override
  String toString() => 'Restaurant($id, $name)';

  @override
  bool operator ==(Object other) =>
      other is Restaurant &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.note == note &&
      other.pendingItemId == pendingItemId;

  @override
  int get hashCode => Object.hash(id, name, createdAt, note, pendingItemId);
}
