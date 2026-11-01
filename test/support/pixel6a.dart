/// The Pixel 6a window, so a layout test fails where the phone would scroll.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes the test window like the Pixel 6a, status bar and nav bar included.
///
/// Physical pixels from `adb shell dumpsys window`: the 40 px an older recipe
/// used was ~15 dp, far below the real 132 px (~50 dp) status bar.
void usePixel6a(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625
    ..padding = const FakeViewPadding(top: 132, bottom: 63)
    ..viewPadding = const FakeViewPadding(top: 132, bottom: 63);
  addTearDown(tester.view.reset);
}

/// Fails when any vertical [Scrollable] on screen has room to scroll.
void expectNoVerticalScroll(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.widget.axis != Axis.vertical) continue;
    expect(
      state.position.maxScrollExtent,
      0,
      reason: 'a vertical Scrollable still scrolls on the Pixel 6a',
    );
  }
}

/// Asserts every widget matched by [finder] can be tapped, and that there are
/// [count] of them (so an empty or clipped grid cannot pass).
void expectAllHittable(Finder finder, {int? count}) {
  final all = finder.evaluate().length;
  expect(all, greaterThan(0));
  expect(finder.hitTestable().evaluate().length, all);
  if (count != null) expect(all, count);
}
