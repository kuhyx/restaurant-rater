/// The app root, and the scope every screen rebuilds through.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/app.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/common/rater_scope.dart';

import 'support/builders.dart';
import 'support/fake_rater_repository.dart';
import 'support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  setUp(() => repository = FakeRaterRepository());
  tearDown(() => repository.dispose());

  testWidgets('RaterApp opens on the restaurants list', (tester) async {
    await tester.pumpWidget(
      RaterApp(
        repository: repository,
        photos: tempPhotoStore(),
        sync: () async => SyncOutcome.synced,
      ),
    );
    await tester.pump();

    expect(find.text('Restaurants'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Restaurant Rater');
    expect(app.theme, isNotNull);
    expect(
      app.darkTheme,
      isNotNull,
      reason: 'both themes come from the shared package',
    );
  });

  group('RaterScope', () {
    testWidgets('rebuilds when a peer write arrives', (tester) async {
      // Not just this device's writes: a rating merged in by a sync tick
      // while the screen is open arrives on the same stream, so the list
      // updates with no pull-to-refresh.
      var builds = 0;
      await pumpScreen(
        tester,
        RaterScope(
          repository: repository,
          builder: (context, RaterSnapshot snapshot) {
            builds++;
            return Text('${snapshot.restaurants.length}');
          },
        ),
      );

      expect(find.text('0'), findsOneWidget);
      final before = builds;

      await repository.addRestaurant(name: 'Tuk Tuk');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(builds, greaterThan(before));
    });

    testWidgets('stops listening once disposed', (tester) async {
      // The store outlives every screen, so a subscription left behind would
      // call setState on a dead State for the rest of the process.
      await pumpScreen(
        tester,
        RaterScope(
          repository: repository,
          builder: (context, snapshot) =>
              Text('${snapshot.restaurants.length}'),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await repository.addRestaurant(name: 'Tuk Tuk');
      await tester.pump();
      // No exception thrown is the assertion; flutter_test fails the test on
      // a setState-after-dispose.
      expect(find.byType(RaterScope), findsNothing);
    });

    testWidgets('reads the snapshot synchronously on first build', (
      tester,
    ) async {
      // Not through a FutureBuilder: the snapshot is already in memory, and
      // awaiting it would flash an empty list on every rebuild.
      repository = FakeRaterRepository(
        restaurants: <Restaurant>[aRestaurant()],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RaterScope(
            repository: repository,
            builder: (context, snapshot) =>
                Text('${snapshot.restaurants.length}'),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
    });
  });
}
