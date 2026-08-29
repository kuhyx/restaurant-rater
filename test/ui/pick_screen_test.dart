/// The pick screen: what it offers, what it commits, and what it says.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/pick_dish.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/ui/pick/pick_actions.dart';
import 'package:restaurant_rater/ui/pick/pick_card.dart';
import 'package:restaurant_rater/ui/pick/pick_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  final soup = aMenuItem(id: 'm1', orderKey: 'a', name: 'tom kha');
  final shrimp = aMenuItem(
    id: 'm2',
    orderKey: 'b',
    name: 'tom yum',
    priceGrosz: 2200,
  );

  tearDown(() => repository.dispose());

  Future<void> open(WidgetTester tester) => pumpScreen(
    tester,
    PickScreen(
      repository: repository,
      photos: tempPhotoStore(),
      restaurantId: 'r1',
    ),
  );

  testWidgets('offers the first dish and commits it', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[shrimp, soup],
    );

    await open(tester);
    await tester.pump();

    expect(find.text('tom kha'), findsOneWidget);
    expect(
      repository.calls,
      contains('commitPick:r1/m1'),
      reason: 'the offer is persisted, which is what makes it survive a kill',
    );
  });

  testWidgets('captions a fresh pick as next, not as "still on this one"', (
    tester,
  ) async {
    // Committing the pick changes what the rule returns, so an un-latched
    // caption would tell a first-time user they had been here before.
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup],
    );

    await open(tester);
    await tester.pump();

    expect(
      find.text(PickCard.captionFor(PickReason.nextUnrated).toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('honours a pick committed before the screen opened', (
    tester,
  ) async {
    // The cold-start case: this is what the user sees walking back to the
    // till, and here "still on this one" is the honest caption.
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant(pendingItemId: 'm2')],
      menuItems: <MenuItem>[soup, shrimp],
    );

    await open(tester);
    await tester.pump();

    expect(find.text('tom yum'), findsOneWidget);
    expect(find.text('22 zł'), findsOneWidget);
    expect(
      find.text(PickCard.captionFor(PickReason.sticky).toUpperCase()),
      findsOneWidget,
    );
    expect(
      repository.calls.where((call) => call.startsWith('commitPick')),
      isEmpty,
      reason: 'already committed: re-writing it would spin the change stream',
    );
  });

  testWidgets('skipping moves on to the next dish', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup, shrimp],
    );

    await open(tester);
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(repository.calls, contains('skipMenuItem:m1'));
    expect(find.text('tom yum'), findsOneWidget);
  });

  testWidgets('disables Skip when there is nothing to switch to', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup],
    );

    await open(tester);
    await tester.pump();

    final skip = tester.widget<PickActions>(find.byType(PickActions));
    expect(skip.canSkip, isFalse);
    expect(find.text('Nothing else left to switch to.'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Skip'),
    );
    expect(button.onPressed, isNull, reason: 'disabled, not merely captioned');
  });

  testWidgets('says the menu is empty rather than offering nothing', (
    tester,
  ) async {
    repository = FakeRaterRepository(restaurants: <Restaurant>[aRestaurant()]);

    await open(tester);
    await tester.pump();

    expect(find.text('No dishes yet'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('says so when the restaurant has been deleted', (tester) async {
    repository = FakeRaterRepository();

    await open(tester);
    await tester.pump();

    expect(find.text('Restaurant is gone'), findsOneWidget);
  });

  testWidgets('offers a round-two dish once everything is rated', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup, shrimp],
      tastings: <Tasting>[
        aTasting(id: 't1', menuItemId: 'm1', eatenAt: kEpoch),
        aTasting(
          id: 't2',
          menuItemId: 'm2',
          eatenAt: kEpoch.subtract(const Duration(days: 30)),
        ),
      ],
    );

    await open(tester);
    await tester.pump();

    expect(find.text('tom yum'), findsOneWidget);
    expect(
      find.text(PickCard.captionFor(PickReason.roundTwo).toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('opens the rating screen from Rate it', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup],
    );

    await open(tester);
    await tester.pump();
    await tester.tap(find.text('Rate it'));
    await tester.pumpAndSettle();

    expect(find.text('Scores'), findsOneWidget);
  });

  testWidgets('opens the menu from the app bar', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[soup],
    );

    await open(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.restaurant_menu));
    await tester.pumpAndSettle();

    expect(find.text('Add dish'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  test('every caption is non-empty except for the empty menu', () {
    for (final reason in PickReason.values) {
      final caption = PickCard.captionFor(reason);
      if (reason == PickReason.emptyMenu) {
        expect(caption, isEmpty);
      } else {
        expect(caption, isNotEmpty, reason: '$reason needs an explanation');
      }
    }
  });
}
