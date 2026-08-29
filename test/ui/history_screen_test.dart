/// The history list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/ui/history/history_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  tearDown(() => repository.dispose());

  Future<void> open(WidgetTester tester) => pumpScreen(
    tester,
    HistoryScreen(repository: repository, photos: tempPhotoStore()),
  );

  testWidgets('says so when nothing has been rated', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);
    expect(find.text('Nothing rated yet'), findsOneWidget);
  });

  testWidgets('lists newest first, with the three axes named in Polish', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[
        aMenuItem(id: 'm1', name: 'tom kha'),
        aMenuItem(id: 'm2', orderKey: 'b', name: 'tom yum'),
      ],
      tastings: <Tasting>[
        aTasting(
          id: 't1',
          menuItemId: 'm1',
          eatenAt: kEpoch.subtract(const Duration(days: 1)),
          taste: 7,
          smell: 6,
          looks: 4,
        ),
        aTasting(
          id: 't2',
          menuItemId: 'm2',
          eatenAt: kEpoch,
          taste: 3,
          smell: 6,
          looks: 6,
        ),
      ],
    );

    await open(tester);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, <String>['tom yum', 'tom kha'], reason: 'newest first');
    expect(find.text('smak 7,0'), findsOneWidget);
    expect(find.text('zapach 6,0'), findsNWidgets(2));
    expect(find.text('estetyka 4,0'), findsOneWidget);
    expect(find.text('5,7'), findsOneWidget);
    expect(find.text('5,0'), findsOneWidget);
    expect(find.text('Bar Tajski'), findsNWidgets(2));
  });

  testWidgets('shows a thumbnail placeholder for a photo from elsewhere', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
      tastings: <Tasting>[aTasting(photoName: 'elsewhere.jpg')],
    );

    await open(tester);

    expect(find.byTooltip('Photo is on another device'), findsOneWidget);
  });

  testWidgets('deletes a rating only after confirmation', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
      tastings: <Tasting>[aTasting()],
    );
    await open(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('deleteTasting:t1'));
    expect(find.text('Nothing rated yet'), findsOneWidget);
  });
}
