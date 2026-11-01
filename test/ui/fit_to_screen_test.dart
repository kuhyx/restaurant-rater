/// Every main screen fits one Pixel 6a screen: no vertical scrolling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/history/history_screen.dart';
import 'package:restaurant_rater/ui/history/tasting_tile.dart';
import 'package:restaurant_rater/ui/menu/menu_item_tile.dart';
import 'package:restaurant_rater/ui/menu/menu_screen.dart';
import 'package:restaurant_rater/ui/pick/pick_screen.dart';
import 'package:restaurant_rater/ui/restaurants/restaurant_tile.dart';
import 'package:restaurant_rater/ui/restaurants/restaurants_screen.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pixel6a.dart';
import '../support/pump.dart';

/// Enough rows to overflow a plain list many times over.
const _many = 40;

void main() {
  late FakeRaterRepository repository;

  tearDown(() => repository.dispose());

  void seed() {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[
        for (var i = 0; i < _many; i++)
          aRestaurant(id: 'r$i', name: 'Bar $i', note: 'by the tram stop'),
      ],
      menuItems: <MenuItem>[
        for (var i = 0; i < _many; i++)
          aMenuItem(id: 'm$i', name: 'tom kha number $i'),
      ],
      tastings: <Tasting>[
        for (var i = 0; i < _many; i++)
          aTasting(
            id: 't$i',
            menuItemId: 'm$i',
            eatenAt: kEpoch.subtract(Duration(days: i)),
          ),
      ],
    );
  }

  testWidgets('Restaurants fits one screen and pages the overflow', (
    tester,
  ) async {
    usePixel6a(tester);
    seed();
    await pumpScreen(
      tester,
      RestaurantsScreen(
        repository: repository,
        photos: tempPhotoStore(),
        sync: () async => SyncOutcome.synced,
        syncProbe: () async => false,
        syncConnect: () async => GoogleSignInStatus.cancelled,
      ),
    );

    expectNoVerticalScroll(tester);
    expectAllHittable(find.byType(RestaurantTile));
    expectAllHittable(find.byType(FloatingActionButton), count: 1);
    expect(find.byKey(const ValueKey<String>('fit-grid-dot-1')), findsOne);
  });

  testWidgets('Menu fits one screen and pages the overflow', (tester) async {
    usePixel6a(tester);
    seed();
    await pumpScreen(
      tester,
      MenuScreen(repository: repository, restaurantId: 'r1'),
    );

    expectNoVerticalScroll(tester);
    expectAllHittable(find.byType(MenuItemTile));
    expectAllHittable(find.byType(FloatingActionButton), count: 1);
    expect(find.byKey(const ValueKey<String>('fit-grid-dot-1')), findsOne);
  });

  testWidgets('History fits one screen and pages the overflow', (tester) async {
    usePixel6a(tester);
    seed();
    await pumpScreen(
      tester,
      HistoryScreen(repository: repository, photos: tempPhotoStore()),
    );

    expectNoVerticalScroll(tester);
    expectAllHittable(find.byType(TastingTile));
    expect(find.byKey(const ValueKey<String>('fit-grid-dot-1')), findsOne);
  });

  testWidgets('Pick is one card with Rate and Skip on screen', (tester) async {
    usePixel6a(tester);
    seed();
    await pumpScreen(
      tester,
      PickScreen(
        repository: repository,
        photos: tempPhotoStore(),
        restaurantId: 'r1',
      ),
    );

    expectNoVerticalScroll(tester);
    expectAllHittable(find.text('Rate it'), count: 1);
    expectAllHittable(find.text('Skip'), count: 1);
  });
}
