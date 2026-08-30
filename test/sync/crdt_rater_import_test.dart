/// Importing a whole menu in one intent, against a real LogStore.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/sync/crdt_rater_repository.dart';

import 'fake_log_persistence.dart';

void main() {
  late LogStore store;
  late CrdtRaterRepository repository;

  setUp(() {
    store = LogStore(persistence: FakeLogPersistence(), nodeId: 'device-a');
    repository = CrdtRaterRepository(store: store);
  });

  Future<String> addRestaurant([String name = 'Bar Tajski']) async {
    await repository.addRestaurant(name: name);
    return repository.snapshot().restaurants.single.id;
  }

  Future<void> addDish(String restaurantId, String name, int? price) =>
      repository.addMenuItem(
        restaurantId: restaurantId,
        name: name,
        priceGrosz: price,
      );

  MenuDraft dish(String name, {int? price, double? kcal}) =>
      (name: name, priceGrosz: price, macros: Macros(kcal: kcal));

  test('creates the restaurant and its menu in the listed order', () async {
    await repository.importMenu(
      restaurantName: '  Pho   Bar ',
      restaurantNote: 'Krupnicza 12',
      dishes: <MenuDraft>[
        dish('tom kha', price: 2400, kcal: 380),
        dish('pad thai', price: 3850),
      ],
    );

    final restaurant = repository.snapshot().restaurants.single;
    expect(restaurant.name, 'Pho Bar', reason: 'cleanName runs on import');
    expect(restaurant.note, 'Krupnicza 12');

    final menu = repository.snapshot().menuOf(restaurant.id);
    expect(menu.map((item) => item.name).toList(), <String>[
      'tom kha',
      'pad thai',
    ]);
    expect(menu.first.priceGrosz, 2400);
    expect(menu.first.macros.kcal, 380);
    expect(menu.last.macros.isEmpty, isTrue);
  });

  test(
    'the menu keys ascend, so the order is the order it was listed',
    () async {
      await repository.importMenu(
        restaurantName: 'Pho Bar',
        dishes: <MenuDraft>[dish('a'), dish('b'), dish('c')],
      );
      final id = repository.snapshot().restaurants.single.id;

      final keys = repository
          .snapshot()
          .menuOf(id)
          .map((item) => item.orderKey)
          .toList();

      expect(keys, orderedEquals(<String>[...keys]..sort()));
      expect(keys.toSet(), hasLength(3), reason: 'no two dishes may collide');
    },
  );

  test('appends to an existing restaurant without renaming it', () async {
    final id = await addRestaurant('Bar Tajski');
    await addDish(id, 'tom kha', 2400);

    await repository.importMenu(
      restaurantName: 'Something Else Entirely',
      intoRestaurantId: id,
      dishes: <MenuDraft>[dish('banh mi', price: 1950)],
    );

    expect(repository.snapshot().restaurants.single.name, 'Bar Tajski');
    expect(
      repository.snapshot().menuOf(id).map((item) => item.name).toList(),
      <String>['tom kha', 'banh mi'],
    );
  });

  test('a target deleted meanwhile writes nothing at all', () async {
    // Otherwise the dishes land as orphans that `snapshotOf` filters out:
    // invisible in the app, and still taking up room on every sync.
    final id = await addRestaurant();
    await repository.deleteRestaurant(id);

    await repository.importMenu(
      restaurantName: 'Bar Tajski',
      intoRestaurantId: id,
      dishes: <MenuDraft>[dish('banh mi')],
    );

    expect(repository.snapshot().menuItems, isEmpty);
  });

  test('an empty dish list still creates the restaurant', () async {
    await repository.importMenu(
      restaurantName: 'Pho Bar',
      dishes: const <MenuDraft>[],
    );

    expect(repository.snapshot().restaurants.single.name, 'Pho Bar');
  });
}
