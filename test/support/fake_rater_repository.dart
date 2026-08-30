/// An in-memory repository, so widget tests need no log, files or clock.
library;

import 'dart:async';

import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';

/// Holds the three lists directly and records what was asked of it.
///
/// Records the *calls*, not just the resulting state, because several of the
/// intents this repository exposes are about what must NOT happen — a rename
/// that leaves the pick alone, a skip that clears it — and a state assertion
/// alone cannot tell a write that was skipped from one that was overwritten.
class FakeRaterRepository implements RaterRepository {
  /// Seeds the fake.
  FakeRaterRepository({
    List<Restaurant>? restaurants,
    List<MenuItem>? menuItems,
    List<Tasting>? tastings,
  }) : restaurants = restaurants ?? <Restaurant>[],
       menuItems = menuItems ?? <MenuItem>[],
       tastings = tastings ?? <Tasting>[];

  /// The restaurants.
  final List<Restaurant> restaurants;

  /// Every dish, across restaurants.
  final List<MenuItem> menuItems;

  /// Every rating, across restaurants.
  final List<Tasting> tastings;

  /// Every mutating call, in order, as `name:arg` strings.
  final List<String> calls = <String>[];

  /// Ids handed out by [newTastingId].
  int _mintedIds = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  /// Closes the change stream. Call from a test's tearDown.
  Future<void> dispose() => _changes.close();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  RaterSnapshot snapshot() => RaterSnapshot(
    restaurants: List<Restaurant>.unmodifiable(restaurants),
    menuItems: List<MenuItem>.unmodifiable(menuItems),
    tastings: List<Tasting>.unmodifiable(tastings),
  );

  @override
  String newTastingId() => 'minted-${_mintedIds++}';

  @override
  Future<void> addRestaurant({required String name, String? note}) async {
    calls.add('addRestaurant:$name/$note');
    restaurants.add(
      Restaurant(
        id: 'new-${restaurants.length}',
        name: name,
        createdAt: DateTime.utc(2026),
        note: note,
      ),
    );
    _notify();
  }

  @override
  Future<void> editRestaurant({
    required String id,
    required String name,
    String? note,
  }) async {
    calls.add('editRestaurant:$id/$name/$note');
    _replaceRestaurant(id, (r) => r.copyWith(name: name, note: () => note));
  }

  @override
  Future<void> deleteRestaurant(String id) async {
    calls.add('deleteRestaurant:$id');
    restaurants.removeWhere((r) => r.id == id);
    menuItems.removeWhere((item) => item.restaurantId == id);
    tastings.removeWhere((t) => t.restaurantId == id);
    _notify();
  }

  @override
  Future<void> addMenuItem({
    required String restaurantId,
    required String name,
    int? priceGrosz,
    Macros macros = Macros.empty,
  }) async {
    calls.add('addMenuItem:$restaurantId/$name/$priceGrosz');
    _appendDish(restaurantId, (
      name: name,
      priceGrosz: priceGrosz,
      macros: macros,
    ));
    _notify();
  }

  void _appendDish(String restaurantId, MenuDraft draft) {
    menuItems.add(
      MenuItem(
        id: 'new-${menuItems.length}',
        restaurantId: restaurantId,
        name: draft.name,
        orderKey: 'k${menuItems.length}',
        priceGrosz: draft.priceGrosz,
        macros: draft.macros,
      ),
    );
  }

  @override
  Future<void> importMenu({
    required String restaurantName,
    required List<MenuDraft> dishes,
    String? restaurantNote,
    String? intoRestaurantId,
  }) async {
    calls.add(
      'importMenu:$restaurantName/$intoRestaurantId/${dishes.length}',
    );
    var restaurantId = intoRestaurantId;
    if (restaurantId == null) {
      restaurantId = 'new-${restaurants.length}';
      restaurants.add(
        Restaurant(
          id: restaurantId,
          name: restaurantName,
          createdAt: DateTime.utc(2026),
          note: restaurantNote,
        ),
      );
    } else if (!restaurants.any((r) => r.id == restaurantId)) {
      return;
    }
    for (final dish in dishes) {
      _appendDish(restaurantId, dish);
    }
    _notify();
  }

  @override
  Future<void> editMenuItem({
    required String id,
    required String name,
    int? priceGrosz,
    Macros macros = Macros.empty,
  }) async {
    calls.add('editMenuItem:$id/$name/$priceGrosz');
    _replaceItem(
      id,
      (item) => item.copyWith(
        name: name,
        priceGrosz: () => priceGrosz,
        macros: macros,
      ),
    );
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    calls.add('deleteMenuItem:$id');
    menuItems.removeWhere((item) => item.id == id);
    tastings.removeWhere((t) => t.menuItemId == id);
    _notify();
  }

  @override
  Future<void> commitPick({
    required String restaurantId,
    required String menuItemId,
  }) async {
    calls.add('commitPick:$restaurantId/$menuItemId');
    _replaceRestaurant(
      restaurantId,
      (r) => r.copyWith(pendingItemId: () => menuItemId),
    );
  }

  @override
  Future<void> clearPick(String restaurantId) async {
    calls.add('clearPick:$restaurantId');
    _replaceRestaurant(
      restaurantId,
      (r) => r.copyWith(pendingItemId: () => null),
    );
  }

  @override
  Future<void> skipMenuItem({
    required String menuItemId,
    required DateTime at,
  }) async {
    calls.add('skipMenuItem:$menuItemId');
    final item = menuItems.where((i) => i.id == menuItemId).firstOrNull;
    if (item == null) return;
    _replaceItem(menuItemId, (i) => i.copyWith(skippedAt: () => at));
    await clearPick(item.restaurantId);
  }

  @override
  Future<void> saveTasting(Tasting tasting) async {
    calls.add('saveTasting:${tasting.menuItemId}');
    tastings.add(tasting);
    _replaceItem(tasting.menuItemId, (i) => i.copyWith(skippedAt: () => null));
    await clearPick(tasting.restaurantId);
  }

  @override
  Future<void> deleteTasting(String id) async {
    calls.add('deleteTasting:$id');
    tastings.removeWhere((t) => t.id == id);
    _notify();
  }

  void _replaceRestaurant(String id, Restaurant Function(Restaurant) update) {
    final index = restaurants.indexWhere((r) => r.id == id);
    if (index < 0) return;
    restaurants[index] = update(restaurants[index]);
    _notify();
  }

  void _replaceItem(String id, MenuItem Function(MenuItem) update) {
    final index = menuItems.indexWhere((item) => item.id == id);
    if (index < 0) return;
    menuItems[index] = update(menuItems[index]);
    _notify();
  }
}
