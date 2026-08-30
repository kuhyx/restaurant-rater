/// Collapsing a burst of writes into one run, plus one follow-up.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/sync/coalesced_tick.dart';

void main() {
  test('runs straight away when nothing is in flight', () async {
    var runs = 0;
    final tick = CoalescedTick(() async => runs++);

    await tick();

    expect(runs, 1);
    expect(tick.isRunning, isFalse);
  });

  test('a burst during one run costs exactly one follow-up', () async {
    // The import case: one write per dish, all landing while the tick the
    // first one triggered is still going out. Thirty dishes must not mean
    // thirty overlapping pushes of very nearly the same bytes.
    var runs = 0;
    final gate = Completer<void>();
    late CoalescedTick tick;
    tick = CoalescedTick(() async {
      runs++;
      if (runs == 1) await gate.future;
    });

    final first = tick();
    await Future<void>.delayed(Duration.zero);
    expect(tick.isRunning, isTrue);

    // Three more writes arrive mid-flight.
    await tick();
    await tick();
    await tick();
    expect(runs, 1, reason: 'nothing may overlap the run in flight');

    gate.complete();
    await first;

    expect(runs, 2, reason: 'one follow-up, not three');
  });

  test('the follow-up sees writes that arrived during the run', () async {
    // Why a trailing run exists at all: a write landing mid-flight is not in
    // the payload already going out, so dropping it would leave the device
    // silently behind until something else happened to write.
    final seen = <int>[];
    var pending = 0;
    late CoalescedTick tick;
    tick = CoalescedTick(() async {
      final taken = pending;
      await Future<void>.delayed(Duration.zero);
      if (taken == 0) {
        pending = 7;
        await tick();
      }
      seen.add(taken);
    });

    await tick();

    expect(seen, <int>[0, 7]);
  });

  test('a failed run does not cancel the follow-up it owes', () async {
    var runs = 0;
    late CoalescedTick tick;
    tick = CoalescedTick(() async {
      runs++;
      if (runs == 1) {
        await tick();
        throw StateError('the push failed');
      }
    });

    await tick();

    expect(runs, 2);
  });
}
