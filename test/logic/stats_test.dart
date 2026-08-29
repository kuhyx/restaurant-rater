/// Per-restaurant progress and dish rankings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/stats.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/tasting.dart';

import '../support/builders.dart';

void main() {
  final soup = aMenuItem(id: 'm1', orderKey: 'a', name: 'tom kha');
  final shrimp = aMenuItem(id: 'm2', orderKey: 'b', name: 'tom yum');

  group('progressOf', () {
    test('counts dishes with at least one tasting', () {
      final progress = progressOf(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', taste: 7, smell: 6, looks: 4),
        ],
      );
      expect(progress.rated, 1);
      expect(progress.total, 2);
      expect(progress.label, '1/2 tried');
      expect(progress.isComplete, isFalse);
      expect(progress.mean, closeTo(5.67, 0.01));
    });

    test('says so when the menu is empty', () {
      final progress = progressOf(
        menu: const <MenuItem>[],
        tastings: const <Tasting>[],
      );
      expect(progress.label, 'no dishes yet');
      expect(progress.isComplete, isFalse, reason: 'an empty menu is not done');
      expect(progress.mean, isNull);
    });

    test('is complete once every dish has been tried', () {
      final progress = progressOf(
        menu: <MenuItem>[soup],
        tastings: <Tasting>[aTasting(menuItemId: 'm1')],
      );
      expect(progress.isComplete, isTrue);
    });
  });

  group('rankedDishes', () {
    test('orders best first and drops the unrated', () {
      final ranked = rankedDishes(
        menu: <MenuItem>[soup, shrimp],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', taste: 3, smell: 3, looks: 3),
        ],
      );
      expect(ranked, hasLength(1), reason: 'tom yum has no score to rank');
      expect(ranked.single.item, soup);
      expect(ranked.single.score, 3.0);
    });

    test('breaks a tie on the dish name', () {
      final ranked = rankedDishes(
        menu: <MenuItem>[shrimp, soup],
        tastings: <Tasting>[
          aTasting(id: 't1', menuItemId: 'm1', taste: 5, smell: 5, looks: 5),
          aTasting(id: 't2', menuItemId: 'm2', taste: 5, smell: 5, looks: 5),
        ],
      );
      expect(ranked.map((entry) => entry.item.name), <String>[
        'tom kha',
        'tom yum',
      ]);
    });
  });
}
