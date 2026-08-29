/// The repository's write intents, against a real LogStore.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/sync/crdt_rater_repository.dart';

import 'fake_log_persistence.dart';
import 'tasting_builder.dart';

void main() {
  late LogStore store;
  late CrdtRaterRepository repository;

  setUp(() {
    store = LogStore(persistence: FakeLogPersistence(), nodeId: 'device-a');
    repository = CrdtRaterRepository(store: store);
  });

  Future<String> addRestaurant([String name = 'Bar Tajski']) async {
    await repository.addRestaurant(name: name, note: 'by the tram stop');
    return repository.snapshot().restaurants.single.id;
  }

  Future<String> addDish(String restaurantId, String name, int? price) async {
    await repository.addMenuItem(
      restaurantId: restaurantId,
      name: name,
      priceGrosz: price,
    );
    return repository
        .snapshot()
        .menuOf(restaurantId)
        .firstWhere((item) => item.name == name)
        .id;
  }

  group('a field-scoped write keeps every other field', () {
    // The regression this whole group exists for: LogStore.upsert REPLACES a
    // record rather than merging into it, so a write naming only the field its
    // intent touches silently deletes the rest. On the first phone build this
    // erased each restaurant's name the moment the pick screen committed a
    // pick, and the screen showed "Restaurant is gone".
    test('committing a pick does not erase the restaurant', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);

      await repository.commitPick(
        restaurantId: restaurantId,
        menuItemId: dishId,
      );

      final restaurant = repository.snapshot().restaurantById(restaurantId);
      expect(restaurant, isNotNull, reason: 'the record must survive a pick');
      expect(restaurant!.name, 'Bar Tajski');
      expect(restaurant.note, 'by the tram stop');
      expect(restaurant.pendingItemId, dishId);
    });

    test('skipping a dish does not erase its name, price or order', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);
      final before = repository.snapshot().menuItemById(dishId)!;

      await repository.skipMenuItem(menuItemId: dishId, at: DateTime.utc(2026));

      final after = repository.snapshot().menuItemById(dishId)!;
      expect(after.name, 'tom kha');
      expect(after.priceGrosz, 2400);
      expect(after.orderKey, before.orderKey);
      expect(after.skippedAt, DateTime.utc(2026));
    });

    test('renaming a restaurant does not erase its committed pick', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);
      await repository.commitPick(
        restaurantId: restaurantId,
        menuItemId: dishId,
      );

      await repository.editRestaurant(id: restaurantId, name: 'Tuk Tuk');

      final restaurant = repository.snapshot().restaurantById(restaurantId)!;
      expect(restaurant.name, 'Tuk Tuk');
      expect(restaurant.pendingItemId, dishId);
    });

    test('renaming a dish does not erase its skip', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);
      await repository.skipMenuItem(menuItemId: dishId, at: DateTime.utc(2026));

      await repository.editMenuItem(id: dishId, name: 'tom kha (duża)');

      final item = repository.snapshot().menuItemById(dishId)!;
      expect(item.name, 'tom kha (duża)');
      expect(item.skippedAt, DateTime.utc(2026));
      expect(item.priceGrosz, isNull, reason: 'the edit cleared the price');
    });
  });

  group('menu order', () {
    test('is the order dishes were added, via a rising orderKey', () async {
      final restaurantId = await addRestaurant();
      await addDish(restaurantId, 'first', null);
      await addDish(restaurantId, 'second', null);
      await addDish(restaurantId, 'third', null);

      final names = repository
          .snapshot()
          .menuOf(restaurantId)
          .map((item) => item.name)
          .toList();
      expect(names, <String>['first', 'second', 'third']);
    });
  });

  group('deleting', () {
    test('a restaurant cascades onto its dishes and their ratings', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);
      await repository.saveTasting(
        aTastingOf(repository, restaurantId, dishId),
      );

      await repository.deleteRestaurant(restaurantId);

      final snapshot = repository.snapshot();
      expect(snapshot.restaurants, isEmpty);
      expect(snapshot.menuItems, isEmpty);
      expect(snapshot.tastings, isEmpty, reason: 'no orphaned ratings');
    });

    test('a dish takes its ratings with it', () async {
      final restaurantId = await addRestaurant();
      final keep = await addDish(restaurantId, 'keep', null);
      final drop = await addDish(restaurantId, 'drop', null);
      await repository.saveTasting(aTastingOf(repository, restaurantId, drop));

      await repository.deleteMenuItem(drop);

      final snapshot = repository.snapshot();
      expect(snapshot.menuOf(restaurantId).single.id, keep);
      expect(snapshot.tastings, isEmpty);
    });
  });

  group('saving a rating', () {
    test('clears the pick and the skip in the same call', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);
      await repository.skipMenuItem(menuItemId: dishId, at: DateTime.utc(2026));
      await repository.commitPick(
        restaurantId: restaurantId,
        menuItemId: dishId,
      );

      await repository.saveTasting(
        aTastingOf(repository, restaurantId, dishId),
      );

      final snapshot = repository.snapshot();
      expect(snapshot.restaurantById(restaurantId)!.pendingItemId, isNull);
      expect(snapshot.menuItemById(dishId)!.skippedAt, isNull);
      expect(snapshot.tastings, hasLength(1));
    });

    test('appends rather than overwriting, so re-tasting keeps both', () async {
      final restaurantId = await addRestaurant();
      final dishId = await addDish(restaurantId, 'tom kha', 2400);

      await repository.saveTasting(
        aTastingOf(repository, restaurantId, dishId, taste: 3),
      );
      await repository.saveTasting(
        aTastingOf(repository, restaurantId, dishId, taste: 9),
      );

      final tastings = repository.snapshot().tastingsOfItem(dishId);
      expect(tastings, hasLength(2));
      expect(
        tastings.map((tasting) => tasting.taste).toSet(),
        <int>{3, 9},
      );
    });
  });

  group('writes against a record that is not there', () {
    test('are no-ops rather than throwing', () async {
      // Reachable for real: a delete merged in from another device between the
      // screen reading a dish and the user acting on it.
      await repository.commitPick(restaurantId: 'ghost', menuItemId: 'gone');
      await repository.clearPick('ghost');
      await repository.skipMenuItem(menuItemId: 'gone', at: DateTime.utc(2026));
      await repository.editRestaurant(id: 'ghost', name: 'x');
      await repository.editMenuItem(id: 'gone', name: 'x');
      expect(repository.snapshot().isEmpty, isTrue);
    });
  });

  test('newTastingId mints a fresh id each time', () {
    expect(repository.newTastingId(), isNot(repository.newTastingId()));
  });

  test('changes fires on every write', () async {
    final seen = <void>[];
    final subscription = repository.changes.listen(seen.add);
    await addRestaurant();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isNotEmpty);
    await subscription.cancel();
  });
}
