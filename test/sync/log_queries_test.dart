/// Decoding a whole log, and refusing to show orphans.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/sync/cascade_delete.dart';
import 'package:restaurant_rater/sync/log_queries.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';

import '../support/builders.dart';

void main() {
  const at = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-a');

  Log logOf(List<Record> records) => <String, Record>{
    for (final record in records) record.id: record,
  };

  final restaurant = restaurantToRecord(aRestaurant(), at);
  final dish = menuItemToRecord(aMenuItem(), at);
  final tasting = tastingToRecord(aTasting(), at);

  test('decodes each kind into its own list', () {
    final snapshot = snapshotOf(logOf(<Record>[restaurant, dish, tasting]));
    expect(snapshot.restaurants, hasLength(1));
    expect(snapshot.menuItems, hasLength(1));
    expect(snapshot.tastings, hasLength(1));
    expect(snapshot.isEmpty, isFalse);
  });

  test('an empty log gives an empty snapshot', () {
    expect(snapshotOf(<String, Record>{}).isEmpty, isTrue);
  });

  test('drops a dish whose restaurant is gone', () {
    // Defence in depth behind the cascade: a cascade written by an older
    // build, or interrupted, would otherwise leave dishes no screen can reach
    // and nothing can delete.
    final snapshot = snapshotOf(logOf(<Record>[dish, tasting]));
    expect(snapshot.menuItems, isEmpty);
    expect(snapshot.tastings, isEmpty, reason: 'and its ratings with it');
  });

  test('drops a rating whose dish is gone', () {
    final snapshot = snapshotOf(logOf(<Record>[restaurant, tasting]));
    expect(snapshot.tastings, isEmpty);
  });

  test('sorts restaurants case-insensitively, id breaking ties', () {
    final snapshot = snapshotOf(
      logOf(<Record>[
        restaurantToRecord(aRestaurant(id: 'r2', name: 'zeta'), at),
        restaurantToRecord(aRestaurant(id: 'r1', name: 'Alpha'), at),
        restaurantToRecord(aRestaurant(id: 'r3', name: 'alpha'), at),
      ]),
    );
    expect(
      snapshot.restaurants.map((r) => r.id),
      <String>['r1', 'r3', 'r2'],
      reason: 'Alpha and alpha sit together, not in two runs of the alphabet',
    );
  });

  group('cascade ids', () {
    test('a restaurant takes its dishes and their ratings', () {
      final ids = idsToTombstoneForRestaurant(
        logOf(<Record>[restaurant, dish, tasting]),
        'r1',
      );
      expect(ids, containsAll(<String>['r:r1', 'm:m1', 't:t1']));
    });

    test('leaves another restaurant alone', () {
      final other = menuItemToRecord(
        aMenuItem(id: 'm9', restaurantId: 'r9'),
        at,
      );
      final ids = idsToTombstoneForRestaurant(
        logOf(<Record>[restaurant, dish, other]),
        'r1',
      );
      expect(ids, isNot(contains('m:m9')));
    });

    test('skips records already tombstoned', () {
      final gone = Record(id: 'm:m1', fields: dish.fields, deleted: true);
      final ids = idsToTombstoneForRestaurant(
        logOf(<Record>[restaurant, gone]),
        'r1',
      );
      expect(ids, <String>['r:r1']);
    });

    test('matches ratings through the dish, not the cached restaurant id', () {
      // The tasting's `restaurant` field is a denormalised cache and can be
      // stale; trusting it would strand a rating instead of deleting it.
      final stale = tastingToRecord(
        aTasting(restaurantId: 'stale-cache'),
        at,
      );
      final ids = idsToTombstoneForRestaurant(
        logOf(<Record>[restaurant, dish, stale]),
        'r1',
      );
      expect(ids, contains('t:t1'));
    });

    test('a dish takes only its own ratings', () {
      final other = tastingToRecord(
        aTasting(id: 't9', menuItemId: 'm9'),
        at,
      );
      final ids = idsToTombstoneForMenuItem(
        logOf(<Record>[dish, tasting, other]),
        'm1',
      );
      expect(ids, <String>['m:m1', 't:t1']);
    });
  });
}
