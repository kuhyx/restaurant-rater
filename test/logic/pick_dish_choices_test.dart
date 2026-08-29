/// The two questions the pick screen asks besides "what next": can a skip
/// actually change anything, and which dish has scored worst.
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

  group('canSkipToAnother', () {
    test('is false with a single unrated dish left', () {
      expect(
        canSkipToAnother(menu: <MenuItem>[soup], tastings: const <Tasting>[]),
        isFalse,
      );
    });

    test('is false when every other dish is already rated', () {
      expect(
        canSkipToAnother(
          menu: <MenuItem>[soup, shrimp],
          tastings: <Tasting>[aTasting(menuItemId: 'm1')],
        ),
        isFalse,
      );
    });

    test('is true with two unrated dishes', () {
      expect(
        canSkipToAnother(
          menu: <MenuItem>[soup, shrimp],
          tastings: const <Tasting>[],
        ),
        isTrue,
      );
    });

    test('is true in round two while more than one dish exists', () {
      expect(
        canSkipToAnother(
          menu: <MenuItem>[soup, shrimp],
          tastings: <Tasting>[
            aTasting(id: 't1', menuItemId: 'm1'),
            aTasting(id: 't2', menuItemId: 'm2'),
          ],
        ),
        isTrue,
      );
    });

    test('is false in round two with only one dish on the menu', () {
      expect(
        canSkipToAnother(
          menu: <MenuItem>[soup],
          tastings: <Tasting>[aTasting(menuItemId: 'm1')],
        ),
        isFalse,
      );
    });
  });

  group('lowestScoring', () {
    test('returns the worst mean, ignoring unrated dishes', () {
      final worst = lowestScoring(
        menu: <MenuItem>[soup, shrimp, curry],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', taste: 9, smell: 9, looks: 9),
          aTasting(id: 't2', menuItemId: 'm2', taste: 1, smell: 1, looks: 1),
        ],
      );
      expect(worst, shrimp);
    });

    test('is null when nothing has been rated', () {
      expect(
        lowestScoring(menu: <MenuItem>[soup], tastings: const <Tasting>[]),
        isNull,
      );
    });

    test('breaks a tie on menu order', () {
      final worst = lowestScoring(
        menu: <MenuItem>[shrimp, soup],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', taste: 2, smell: 2, looks: 2),
          aTasting(id: 't2', menuItemId: 'm2', taste: 2, smell: 2, looks: 2),
        ],
      );
      expect(worst, soup);
    });
  });
}
