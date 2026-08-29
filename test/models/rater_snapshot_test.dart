/// The one-read view every screen builds from.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';

import '../support/builders.dart';

void main() {
  final snapshot = RaterSnapshot(
    restaurants: <Restaurant>[aRestaurant()],
    menuItems: <MenuItem>[
      aMenuItem(id: 'm2', orderKey: 'b'),
      aMenuItem(id: 'm1', orderKey: 'a'),
      aMenuItem(id: 'm9', restaurantId: 'other', orderKey: 'a'),
    ],
    tastings: <Tasting>[
      aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
      aTasting(
        id: 't2',
        menuItemId: 'm1',
        eatenAt: kEpoch.add(const Duration(days: 1)),
        photoName: 'p.jpg',
      ),
      aTasting(id: 't9', menuItemId: 'm9', restaurantId: 'other'),
    ],
  );

  test('empty is empty', () {
    expect(RaterSnapshot.empty.isEmpty, isTrue);
    expect(snapshot.isEmpty, isFalse);
  });

  test('looks up by id, returning null when absent', () {
    expect(snapshot.restaurantById('r1')!.name, 'Bar Tajski');
    expect(snapshot.restaurantById('nope'), isNull);
    expect(snapshot.menuItemById('m1')!.id, 'm1');
    expect(snapshot.menuItemById('nope'), isNull);
  });

  test('menuOf returns only that restaurant, in entry order', () {
    expect(snapshot.menuOf('r1').map((item) => item.id), <String>['m1', 'm2']);
  });

  test('tastingsOf filters by restaurant', () {
    expect(snapshot.tastingsOf('r1'), hasLength(2));
  });

  test('tastingsOfItem is newest first', () {
    expect(
      snapshot.tastingsOfItem('m1').map((tasting) => tasting.id),
      <String>['t2', 't1'],
    );
  });

  test('referencedPhotos names every live photo exactly once', () {
    // This is the set the orphan sweep keeps; anything missing from it gets
    // deleted, so a false negative here costs a photo.
    expect(snapshot.referencedPhotos(), <String>{'p.jpg'});
  });
}
