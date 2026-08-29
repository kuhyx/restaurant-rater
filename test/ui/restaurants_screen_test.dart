/// Home: the list, the add dialog, and where a tap goes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';
import 'package:restaurant_rater/ui/restaurants/restaurants_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  tearDown(() => repository.dispose());

  Future<void> open(WidgetTester tester) => pumpScreen(
    tester,
    RestaurantsScreen(
      repository: repository,
      photos: tempPhotoStore(),
      sync: () async => SyncOutcome.synced,
      // Both reach platform channels flutter_test has no host for, and an
      // unanswered channel hangs the whole file rather than failing it.
      syncProbe: () async => false,
      syncConnect: () async => GoogleSignInStatus.cancelled,
    ),
  );

  testWidgets('says what to do when there is nothing yet', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);
    expect(find.text('No restaurants yet'), findsOneWidget);
  });

  testWidgets('shows progress and the mean score', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant(note: 'by the tram stop')],
      menuItems: <MenuItem>[
        aMenuItem(id: 'm1', orderKey: 'a'),
        aMenuItem(id: 'm2', orderKey: 'b'),
      ],
      tastings: <Tasting>[
        aTasting(menuItemId: 'm1', taste: 7, smell: 6, looks: 4),
      ],
    );

    await open(tester);

    expect(find.text('Bar Tajski'), findsOneWidget);
    expect(find.text('by the tram stop  ·  1/2 tried'), findsOneWidget);
    expect(find.text('5,7'), findsOneWidget);
  });

  testWidgets('omits the note when there is none', (tester) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
    );
    await open(tester);
    expect(find.text('no dishes yet'), findsOneWidget);
  });

  testWidgets('adds a restaurant through the dialog', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tuk Tuk');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('addRestaurant:Tuk Tuk/null'));
    expect(find.text('Tuk Tuk'), findsOneWidget);
  });

  testWidgets('will not save a nameless restaurant', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('cancelling the dialog writes nothing', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('keeps the note when one is typed', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Tuk Tuk');
    await tester.enterText(find.byType(TextField).at(1), 'ul. Koszykowa');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('addRestaurant:Tuk Tuk/ul. Koszykowa'));
  });

  testWidgets('a tap goes to the pick, the menu icon to the menu', (
    tester,
  ) async {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
    );

    await open(tester);
    await tester.tap(find.text('Bar Tajski'));
    await tester.pumpAndSettle();
    expect(find.text('Rate it'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restaurant_menu));
    await tester.pumpAndSettle();
    expect(find.text('24 zł  ·  not tried yet'), findsOneWidget);
  });

  testWidgets('opens history and settings from the app bar', (tester) async {
    repository = FakeRaterRepository();
    await open(tester);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Sync now'), findsOneWidget);
  });
}
