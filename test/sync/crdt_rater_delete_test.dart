/// Deleting, and everything a delete has to take with it.
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
}
