/// The three record types: copyWith, equality, and their derived reads.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';

import '../support/builders.dart';

void main() {
  group('Restaurant', () {
    test('copyWith replaces only what it is given', () {
      final original = aRestaurant(note: 'by the tram stop');
      expect(original.copyWith(name: 'Tuk Tuk').name, 'Tuk Tuk');
      expect(original.copyWith(name: 'Tuk Tuk').note, 'by the tram stop');
      expect(original.copyWith().note, 'by the tram stop');
      expect(original.copyWith(createdAt: kEpoch).createdAt, kEpoch);
    });

    test('copyWith can clear the pick, which is what rating does', () {
      final committed = aRestaurant(pendingItemId: 'm1');
      expect(
        committed.copyWith(pendingItemId: () => null).pendingItemId,
        isNull,
      );
      expect(committed.copyWith().pendingItemId, 'm1');
      expect(committed.copyWith(note: () => 'x').note, 'x');
    });

    test('has value equality', () {
      expect(aRestaurant(), aRestaurant());
      expect(aRestaurant().hashCode, aRestaurant().hashCode);
      expect(aRestaurant(), isNot(aRestaurant(name: 'other')));
      expect(aRestaurant(), isNot(aRestaurant(id: 'other')));
      expect(aRestaurant(), isNot(aRestaurant(note: 'x')));
      expect(aRestaurant(), isNot(aRestaurant(pendingItemId: 'x')));
      expect(aRestaurant(), isNot(aRestaurant(createdAt: DateTime.utc(1999))));
      expect(aRestaurant(), isNot(7));
      expect(aRestaurant().toString(), contains('Bar Tajski'));
    });
  });

  group('MenuItem', () {
    test('reports whether it has been passed over', () {
      expect(aMenuItem().isSkipped, isFalse);
      expect(aMenuItem(skippedAt: kEpoch).isSkipped, isTrue);
    });

    test('copyWith can clear the price and the skip independently', () {
      final skipped = aMenuItem(skippedAt: kEpoch);
      expect(skipped.copyWith(priceGrosz: () => null).priceGrosz, isNull);
      expect(skipped.copyWith(priceGrosz: () => null).skippedAt, kEpoch);
      expect(skipped.copyWith(skippedAt: () => null).skippedAt, isNull);
      expect(skipped.copyWith(name: 'x').name, 'x');
      expect(skipped.copyWith(orderKey: 'z').orderKey, 'z');
      expect(skipped.copyWith().skippedAt, kEpoch);
    });

    test('has value equality', () {
      expect(aMenuItem(), aMenuItem());
      expect(aMenuItem().hashCode, aMenuItem().hashCode);
      expect(aMenuItem(), isNot(aMenuItem(id: 'other')));
      expect(aMenuItem(), isNot(aMenuItem(restaurantId: 'other')));
      expect(aMenuItem(), isNot(aMenuItem(name: 'other')));
      expect(aMenuItem(), isNot(aMenuItem(orderKey: 'other')));
      expect(aMenuItem(), isNot(aMenuItem(priceGrosz: 1)));
      expect(aMenuItem(), isNot(aMenuItem(skippedAt: kEpoch)));
      expect(aMenuItem(), isNot(7));
      expect(aMenuItem().toString(), contains('tom kha'));
    });
  });

  group('Tasting', () {
    test('copyWith replaces and clears', () {
      final rated = aTasting(note: 'too salty', photoName: 'p.jpg');
      expect(rated.copyWith(taste: 9).taste, 9);
      expect(rated.copyWith(smell: 9).smell, 9);
      expect(rated.copyWith(looks: 9).looks, 9);
      expect(rated.copyWith(eatenAt: kEpoch).eatenAt, kEpoch);
      expect(rated.copyWith(macros: const Macros(kcal: 1)).macros.kcal, 1);
      expect(rated.copyWith(note: () => null).note, isNull);
      expect(rated.copyWith(photoName: () => null).photoName, isNull);
      expect(rated.copyWith(priceGrosz: () => 500).priceGrosz, 500);
      expect(rated.copyWith().note, 'too salty');
    });

    test('has value equality', () {
      expect(aTasting(), aTasting());
      expect(aTasting().hashCode, aTasting().hashCode);
      expect(aTasting(), isNot(aTasting(id: 'other')));
      expect(aTasting(), isNot(aTasting(menuItemId: 'other')));
      expect(aTasting(), isNot(aTasting(restaurantId: 'other')));
      expect(aTasting(), isNot(aTasting(taste: 1)));
      expect(aTasting(), isNot(aTasting(smell: 1)));
      expect(aTasting(), isNot(aTasting(looks: 1)));
      expect(aTasting(), isNot(aTasting(eatenAt: DateTime.utc(1999))));
      expect(aTasting(), isNot(aTasting(macros: const Macros(kcal: 1))));
      expect(aTasting(), isNot(aTasting(photoName: 'p.jpg')));
      expect(aTasting(), isNot(aTasting(note: 'x')));
      expect(aTasting(), isNot(aTasting(priceGrosz: 1)));
      expect(aTasting(), isNot(7));
      expect(aTasting().toString(), contains('7/6/4'));
    });
  });
}
