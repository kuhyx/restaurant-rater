/// Settings: the one place that reports what a sync actually did.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';
import 'package:restaurant_rater/ui/settings/settings_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;

  setUp(() {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
      tastings: <Tasting>[aTasting()],
    );
  });

  tearDown(() => repository.dispose());

  Future<void> open(
    WidgetTester tester, {
    required Future<SyncOutcome> Function() sync,
    bool connected = false,
  }) => pumpScreen(
    tester,
    SettingsScreen(
      repository: repository,
      sync: sync,
      syncProbe: () async => connected,
      syncConnect: () async => GoogleSignInStatus.cancelled,
    ),
  );

  testWidgets('counts what this device holds', (tester) async {
    await open(tester, sync: () async => SyncOutcome.synced);
    await tester.pumpAndSettle();
    expect(find.text('1 restaurants, 1 dishes, 1 ratings'), findsOneWidget);
  });

  testWidgets('reports a successful sync', (tester) async {
    await open(tester, sync: () async => SyncOutcome.synced);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Synced.'), findsOneWidget);
  });

  testWidgets('says plainly when this device is not connected', (tester) async {
    // The whole reason this button exists: the automatic push is
    // fire-and-forget and swallows this outcome, so without a report here a
    // device that never syncs looks identical to one that always does.
    await open(tester, sync: () async => SyncOutcome.notConfigured);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not connected — nothing was pushed or pulled.'),
      findsOneWidget,
    );
  });

  testWidgets('surfaces a sync failure rather than swallowing it', (
    tester,
  ) async {
    await open(tester, sync: () async => throw StateError('no network'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync failed:'), findsOneWidget);
  });

  testWidgets('shows the connected state read back from the keystore', (
    tester,
  ) async {
    await open(
      tester,
      sync: () async => SyncOutcome.synced,
      connected: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sync connected'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('offers to connect when there is no session', (tester) async {
    await open(tester, sync: () async => SyncOutcome.synced);
    await tester.pumpAndSettle();
    expect(find.text('Connect Google account'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('a cancelled sign-in stays quiet', (tester) async {
    await open(tester, sync: () async => SyncOutcome.synced);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'a choice, not a fault',
    );
  });

  testWidgets('states the photo limitation on the screen', (tester) async {
    await open(tester, sync: () async => SyncOutcome.synced);
    await tester.pumpAndSettle();
    expect(
      find.text('Photos stay on the device that took them'),
      findsOneWidget,
    );
  });
}
