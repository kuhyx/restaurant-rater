/// The menu: entry order, editing, and deleting with its ratings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/ui/menu/menu_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  tearDown(() => repository.dispose());

  Future<void> open(WidgetTester tester) => pumpScreen(
    tester,
    MenuScreen(repository: repository, restaurantId: 'r1'),
  );

  testWidgets('says what to do with an empty menu', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
    );
    await open(tester);
    expect(find.text('No dishes yet'), findsOneWidget);
    expect(find.text('Bar Tajski'), findsOneWidget);
  });

  testWidgets('falls back to a generic title when the place is gone', (
    tester,
  ) async {
    repository = FakeRaterRepository();
    await open(tester);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('lists dishes in entry order with prices and state', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[
        aMenuItem(id: 'm2', orderKey: 'b', name: 'tom yum', priceGrosz: 2200),
        aMenuItem(
          id: 'm1',
          orderKey: 'a',
          name: 'tom kha',
          skippedAt: kEpoch,
        ),
      ],
      tastings: <Tasting>[
        aTasting(menuItemId: 'm2', taste: 3, smell: 6, looks: 6),
      ],
    );

    await open(tester);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, <String>['tom kha', 'tom yum']);
    expect(find.text('24 zł  ·  not tried yet  ·  skipped'), findsOneWidget);
    expect(find.text('22 zł'), findsOneWidget);
    expect(find.text('5,0'), findsOneWidget);
  });

  testWidgets('adds a dish with a price', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
    );
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'pad thai');
    await tester.enterText(find.byType(TextField).at(1), '28,50');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('addMenuItem:r1/pad thai/2850'));
  });

  testWidgets('a blank price means no price, not a zero', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
    );
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'pad thai');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('addMenuItem:r1/pad thai/null'));
  });

  testWidgets('edits a dish, pre-filling its current price', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
    );
    await open(tester);

    await tester.tap(find.text('tom kha z kurczakiem'));
    await tester.pumpAndSettle();
    // Read the field itself: "24" also appears in the tile behind the dialog.
    final price = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(price.controller!.text, '24', reason: 'price pre-filled, unit off');
    await tester.enterText(find.byType(TextField).at(0), 'tom kha (duża)');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('editMenuItem:m1/tom kha (duża)/2400'));
  });

  testWidgets('deletes a dish only after confirmation', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
    );
    await open(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty, reason: 'cancel means cancel');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('deleteMenuItem:m1'));
  });

  testWidgets('cancelling the add dialog writes nothing', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
    );
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
  });

  testWidgets('a dish shows what the menu claimed it contains', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem(macros: const Macros(kcal: 380.4))],
    );
    await open(tester);

    expect(find.textContaining('380 kcal'), findsOneWidget);
  });
}
