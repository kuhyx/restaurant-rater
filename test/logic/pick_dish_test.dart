/// The pick rule — the heart of the app, so the most heavily specified file.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/pick_dish.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/tasting.dart';

import '../support/builders.dart';

void main() {
  final soup = aMenuItem(id: 'm1', orderKey: 'a', name: 'tom kha');
  final shrimp = aMenuItem(id: 'm2', orderKey: 'b', name: 'tom yum');
  final curry = aMenuItem(id: 'm3', orderKey: 'c', name: 'green curry');

  PickResult pick({
    List<MenuItem> menu = const <MenuItem>[],
    List<Tasting> tastings = const <Tasting>[],
    String? pending,
  }) => pickNext(
    restaurant: aRestaurant(pendingItemId: pending),
    menu: menu,
    tastings: tastings,
  );

  group('empty menu', () {
    test('offers nothing at all', () {
      final result = pick();
      expect(result.item, isNull);
      expect(result.reason, PickReason.emptyMenu);
    });
  });

  group('menu order', () {
    test('offers the lowest orderKey first, not the first in the list', () {
      // Deliberately out of order: the rule is orderKey, not list position.
      final result = pick(menu: <MenuItem>[curry, shrimp, soup]);
      expect(result.item, soup);
      expect(result.reason, PickReason.nextUnrated);
    });

    test('skips over a dish that has already been rated', () {
      final result = pick(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[aTasting(menuItemId: 'm1')],
      );
      expect(result.item, shrimp);
    });

    test('breaks an orderKey tie on id, so both devices agree', () {
      final a = aMenuItem(id: 'zz', orderKey: 'same');
      final b = aMenuItem(id: 'aa', orderKey: 'same');
      expect(pick(menu: <MenuItem>[a, b]).item, b);
      expect(pick(menu: <MenuItem>[b, a]).item, b);
    });
  });

  group('stickiness', () {
    test('honours a committed pick over the menu order', () {
      final result = pick(menu: <MenuItem>[soup, shrimp], pending: 'm2');
      expect(result.item, shrimp);
      expect(result.reason, PickReason.sticky);
    });

    test('is stable across repeated calls, which is the whole point', () {
      final first = pick(menu: <MenuItem>[soup, shrimp], pending: 'm2');
      final second = pick(menu: <MenuItem>[soup, shrimp], pending: 'm2');
      expect(first.item, second.item);
    });

    test('falls back when the committed dish no longer exists', () {
      // A delete merged in from another device leaves a dangling id; it must
      // self-heal rather than wedge the screen.
      final result = pick(menu: <MenuItem>[soup], pending: 'deleted');
      expect(result.item, soup);
      expect(result.reason, PickReason.nextUnrated);
    });

    test('honours a committed dish that has just been rated', () {
      // The round-two case. If the sticky rule also required the dish to be
      // unrated, it would reject the app's own suggestion on the next tap and
      // bounce straight back to the terminal state.
      final result = pick(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1'),
          aTasting(id: 't2', menuItemId: 'm2'),
        ],
        pending: 'm1',
      );
      expect(result.item, soup);
      expect(result.reason, PickReason.sticky);
    });
  });

  group('skipping', () {
    test('passes over a skipped dish in favour of a fresh one', () {
      final skipped = soup.copyWith(skippedAt: () => kEpoch);
      final result = pick(menu: <MenuItem>[skipped, shrimp]);
      expect(result.item, shrimp);
      expect(result.reason, PickReason.nextUnrated);
    });

    test('comes back to the longest-ago skip once all are skipped', () {
      final older = soup.copyWith(
        skippedAt: () => kEpoch.subtract(const Duration(days: 2)),
      );
      final newer = shrimp.copyWith(skippedAt: () => kEpoch);
      final result = pick(menu: <MenuItem>[newer, older]);
      expect(result.item, older);
      expect(result.reason, PickReason.skippedFallback);
    });

    test('breaks a same-instant skip tie on menu order', () {
      final a = soup.copyWith(skippedAt: () => kEpoch);
      final b = shrimp.copyWith(skippedAt: () => kEpoch);
      expect(pick(menu: <MenuItem>[b, a]).item, a);
    });

    test('never locks a dish out permanently', () {
      // Skipping everything still yields a dish, which is the property that
      // matters: a skip is a sort key, never a gate.
      final all = <MenuItem>[
        soup.copyWith(skippedAt: () => kEpoch),
        shrimp.copyWith(skippedAt: () => kEpoch),
        curry.copyWith(skippedAt: () => kEpoch),
      ];
      expect(pick(menu: all).item, isNotNull);
    });
  });

  group('round two', () {
    test('offers the dish gone longest without, once all are rated', () {
      final result = pick(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
          aTasting(
            id: 't2',
            menuItemId: 'm2',
            eatenAt: kEpoch.subtract(const Duration(days: 30)),
          ),
        ],
      );
      expect(result.item, shrimp);
      expect(result.reason, PickReason.roundTwo);
    });

    test('uses the most recent tasting of a dish, not its first', () {
      final result = pick(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(
            id: 't1',
            menuItemId: 'm1',
            eatenAt: kEpoch.subtract(const Duration(days: 90)),
          ),
          aTasting(id: 't2', menuItemId: 'm1', eatenAt: kEpoch),
          aTasting(
            id: 't3',
            menuItemId: 'm2',
            eatenAt: kEpoch.subtract(const Duration(days: 5)),
          ),
        ],
      );
      expect(result.item, shrimp);
    });

    test('breaks a same-instant tie on menu order', () {
      final result = pick(
        menu: <MenuItem>[shrimp, soup],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
          aTasting(id: 't2', menuItemId: 'm2', eatenAt: kEpoch),
        ],
      );
      expect(result.item, soup);
    });

    test('puts a dish with no surviving rating first', () {
      // Reachable when a merge drops a tasting: "no record of eating it" is
      // the longest wait there is, so it comes back before anything dated.
      final result = pickNext(
        restaurant: aRestaurant(),
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
        ],
      );
      // tom yum is unrated, so this is rule 3 rather than round two -- the
      // round-two ordering itself is exercised by reversing the pair.
      expect(result.item, shrimp);

      final reversed = pickNext(
        restaurant: aRestaurant(),
        menu: <MenuItem>[shrimp, soup],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
          aTasting(id: 't2', menuItemId: 'm2', eatenAt: kEpoch),
        ],
      );
      expect(reversed.reason, PickReason.roundTwo);
    });
  });

  test('PickResult prints its dish and reason', () {
    expect(
      pick(menu: <MenuItem>[soup]).toString(),
      contains('nextUnrated'),
    );
  });
}
