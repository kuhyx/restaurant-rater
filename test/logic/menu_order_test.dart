/// Ordering that has to come out the same on every device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/menu_order.dart';
import 'package:restaurant_rater/models/menu_item.dart';

import '../support/builders.dart';

void main() {
  test('byOrderKey sorts on the key, then the id', () {
    final a = aMenuItem(id: 'zz', orderKey: 'a');
    final b = aMenuItem(id: 'aa', orderKey: 'b');
    expect(byOrderKey(a, b), lessThan(0));
    expect(byOrderKey(b, a), greaterThan(0));

    final tieHigh = aMenuItem(id: 'zz', orderKey: 'same');
    final tieLow = aMenuItem(id: 'aa', orderKey: 'same');
    expect(byOrderKey(tieHigh, tieLow), greaterThan(0));
    expect(byOrderKey(tieLow, tieLow), 0);
  });

  test('sortedByOrderKey does not mutate its input', () {
    final input = <MenuItem>[
      aMenuItem(id: 'b', orderKey: 'b'),
      aMenuItem(id: 'a', orderKey: 'a'),
    ];
    final sorted = sortedByOrderKey(input);
    expect(sorted.first.id, 'a');
    expect(input.first.id, 'b', reason: 'the caller keeps its own order');
  });

  group('bySkippedAtThenOrder', () {
    test('puts a never-skipped dish first: it has waited longest', () {
      final fresh = aMenuItem(id: 'a', orderKey: 'z');
      final skipped = aMenuItem(id: 'b', orderKey: 'a', skippedAt: kEpoch);
      expect(bySkippedAtThenOrder(fresh, skipped), lessThan(0));
      expect(bySkippedAtThenOrder(skipped, fresh), greaterThan(0));
    });

    test('orders two skips oldest first', () {
      final old = aMenuItem(
        id: 'a',
        skippedAt: kEpoch.subtract(const Duration(days: 1)),
      );
      final recent = aMenuItem(id: 'b', skippedAt: kEpoch);
      expect(bySkippedAtThenOrder(old, recent), lessThan(0));
    });

    test('breaks a same-instant tie on menu order', () {
      final first = aMenuItem(id: 'a', orderKey: 'a', skippedAt: kEpoch);
      final second = aMenuItem(id: 'b', orderKey: 'b', skippedAt: kEpoch);
      expect(bySkippedAtThenOrder(first, second), lessThan(0));
    });

    test('two never-skipped dishes fall through to menu order', () {
      expect(
        bySkippedAtThenOrder(
          aMenuItem(id: 'a', orderKey: 'a'),
          aMenuItem(id: 'b', orderKey: 'b'),
        ),
        lessThan(0),
      );
    });
  });
}
