import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';
import 'package:restaurant_rater/ui/settings/sync_actions.dart';

/// Covers the connect tile, whose whole job is to stop sync failing silently.
///
/// The state is deliberately read back from the probe after every attempt
/// rather than assumed, so these tests pin that the tile reports what the
/// keystore actually holds -- not what the last tap hoped for.
void main() {
  /// Pumps the tile with [probe] and [connect] standing in for the platform.
  Future<void> pump(
    WidgetTester tester, {
    required SyncProbe probe,
    SyncConnect? connect,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SyncActions(
          probe: probe,
          connect: connect ?? () async => GoogleSignInStatus.succeeded,
        ),
      ),
    ),
  );

  testWidgets('shows a spinner until the probe answers', (tester) async {
    await pump(tester, probe: () async => false);

    // Still in flight: the first frame must not claim either state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('offers to connect when there is no session', (tester) async {
    await pump(tester, probe: () async => false);
    await tester.pumpAndSettle();

    expect(find.text('Connect Google account'), findsOneWidget);
    expect(
      find.text('Until this is connected, ratings stay on this device only.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('reports a device that already has a session', (tester) async {
    await pump(tester, probe: () async => true);
    await tester.pumpAndSettle();

    expect(find.text('Sync connected'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('a successful connect flips the tile', (tester) async {
    var connected = false;
    await pump(
      tester,
      probe: () async => connected,
      connect: () async {
        connected = true;
        return GoogleSignInStatus.succeeded;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    expect(find.text('Sync connected'), findsOneWidget);
  });

  testWidgets('a dismissed picker leaves it not connected', (tester) async {
    var attempts = 0;
    await pump(
      tester,
      probe: () async => false,
      connect: () async {
        attempts++;
        // What the picker reports when the user backs out.
        return GoogleSignInStatus.cancelled;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    // Backing out is a choice, not an error: no snackbar, no state change.
    expect(find.text('Connect Google account'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed sign-in surfaces the reason', (tester) async {
    await pump(
      tester,
      probe: () async => false,
      connect: () async => throw StateError('wrong uid'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    // A misconfiguration the user has to see -- silently staying on "Not
    // connected" is what made this whole tile necessary.
    expect(find.textContaining('Sign-in failed'), findsOneWidget);
    expect(find.textContaining('wrong uid'), findsOneWidget);
  });

  testWidgets('a refusal names the unregistered client', (tester) async {
    await pump(
      tester,
      probe: () async => false,
      connect: () async =>
          throw const GoogleSignInRefused('UNREGISTERED_ON_API_CONSOLE'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    // The exact on-device failure this tile was blind to: Google's own words
    // reach the screen, so the console entry is the obvious next step.
    expect(
      find.textContaining('UNREGISTERED_ON_API_CONSOLE'),
      findsOneWidget,
    );
  });

  testWidgets('a retry runs the sign-in again', (tester) async {
    var attempts = 0;
    await pump(
      tester,
      probe: () async => false,
      connect: () async {
        attempts++;
        throw const GoogleSignInRefused('nope');
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  testWidgets('a sign-in that stores no session says so', (tester) async {
    await pump(
      tester,
      // Reports success, yet the keystore still holds nothing: the silent
      // "connected but never syncs" state the whole feature exists to catch.
      probe: () async => false,
      connect: () async => GoogleSignInStatus.succeeded,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect Google account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no session was stored'), findsOneWidget);
    expect(find.text('Connect Google account'), findsOneWidget);
  });

  testWidgets('an already-connected tile is not tappable', (tester) async {
    var attempts = 0;
    await pump(
      tester,
      probe: () async => true,
      connect: () async {
        attempts++;
        return GoogleSignInStatus.succeeded;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync connected'));
    await tester.pumpAndSettle();

    expect(attempts, isZero);
  });

  testWidgets('does not set state after being disposed', (tester) async {
    // A probe that answers after the screen is gone must not throw.
    await pump(
      tester,
      probe: () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return true;
      },
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
