/// Connecting this device to the shared sync account.
library;

import 'dart:async';

import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';

/// The project's **Web** OAuth client id.
///
/// Web, not Android: `google_sign_in` wants the server client id, and hands
/// back an id token minted for it. Shared with the sibling apps because they
/// all sign in to the same `kuhy-syncs` project.
const String kServerClientId =
    '845446124781-prdoherj0v64vc6egvvcp3l0693khaur.apps.googleusercontent.com';

/// Whether this device already holds a usable session.
typedef SyncProbe = Future<bool> Function();

/// Runs the interactive sign-in and says which of three things happened.
typedef SyncConnect = Future<GoogleSignInStatus> Function();

/// The real probe: asks the keystore, not a local flag.
///
/// Reads through the package's default storage, so a test covers this by
/// installing the shared secure-storage fake rather than by passing a stub.
Future<bool> probeSyncSession() => isSyncConfigured(kSyncApp);

/// The real connect: raises the Google picker, then signs in to Firebase.
///
/// Reports the three outcomes apart, which is the whole point of this
/// function. A dismissed picker is a choice and stays quiet; a refusal from
/// Google -- an unregistered client, a wrong SHA-1 -- is thrown with its
/// reason attached, because the previous version returned the same `false`
/// for both and left the user tapping a tile that did nothing.
///
/// [platform] replaces the account picker, which reaches a platform channel
/// `flutter test` has no host for; [httpClient] replaces the Firebase token
/// exchange. Both default to the real thing.
Future<GoogleSignInStatus> connectSyncAccount({
  GoogleSignInPlatform? platform,
  http.Client? httpClient,
}) async {
  final attempt = await googleSignInAttempt(
    serverClientId: kServerClientId,
    platform: platform,
  );
  if (attempt.status != GoogleSignInStatus.succeeded) {
    if (attempt.status == GoogleSignInStatus.failed) {
      throw GoogleSignInRefused(attempt.detail!);
    }
    return GoogleSignInStatus.cancelled;
  }
  final client = await signInWithGoogle(
    kSyncApp,
    tokenFetcher: () async => attempt.idToken,
    httpClient: httpClient,
  );
  client?.close();
  // Non-null here by construction: the token was minted above, so
  // `signInWithGoogle` either returns a client or throws.
  return GoogleSignInStatus.succeeded;
}

/// Google declined to mint a token, with the reason it gave.
///
/// A named type rather than a bare [StateError] so the tile can show Google's
/// own words -- "unregistered client" is actionable, "sign-in failed" is not.
class GoogleSignInRefused implements Exception {
  /// Creates a refusal described by [reason].
  const GoogleSignInRefused(this.reason);

  /// Google's explanation, as close to verbatim as the plugin surfaces it.
  final String reason;

  @override
  String toString() => reason;
}

/// Shows whether this device syncs, and connects it when it does not.
///
/// Without this the app is silently local-only: `openSync` returns null on a
/// device with no session, every push no-ops, and nothing says so. The state
/// is read back from the keystore rather than remembered, because a revoked
/// token would otherwise leave this reading "Connected" while every sync
/// failed.
class SyncActions extends StatefulWidget {
  /// Creates the sync section.
  ///
  /// Both platform calls are injected so a widget test never reaches Google
  /// or the keystore -- an unanswered channel would hang the whole test file
  /// rather than fail it.
  const SyncActions({
    this.probe = probeSyncSession,
    this.connect = connectSyncAccount,
    super.key,
  });

  /// Reports whether a session exists.
  final SyncProbe probe;

  /// Performs the interactive sign-in.
  final SyncConnect connect;

  @override
  State<SyncActions> createState() => _SyncActionsState();
}

class _SyncActionsState extends State<SyncActions> {
  bool _connected = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final connected = await widget.probe();
    if (!mounted) {
      return;
    }
    setState(() {
      _connected = connected;
      _busy = false;
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final failure = await _attempt();
    await _refresh();
    if (!mounted || failure == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Retry', onPressed: _connect),
      ),
    );
  }

  /// Runs one sign-in and returns the message to show, or null for silence.
  ///
  /// Only a dismissed picker is silent. Every other ending -- Google refusing,
  /// Firebase rejecting the token, or a sign-in that reports success while the
  /// keystore ends up with no session -- produces a message, because a tile
  /// that exists to stop sync failing silently must not fail silently itself.
  Future<String?> _attempt() async {
    try {
      final status = await widget.connect();
      if (status == GoogleSignInStatus.cancelled) {
        return null;
      }
    } on Object catch (error) {
      // Surfaced rather than swallowed: a wrong-uid or unregistered-client
      // failure is a misconfiguration the user has to see, not a silent
      // return to "Not connected".
      return 'Sign-in failed: $error';
    }
    if (await widget.probe()) {
      return null;
    }
    // Google said yes and the keystore still holds nothing. Reporting success
    // here is what "connected but never syncs" looks like from the outside.
    return 'Signed in, but no session was stored: this device will not sync.';
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(_connected ? 'Sync connected' : 'Connect Google account'),
    subtitle: Text(
      _connected
          ? 'This device syncs its ratings with your other devices.'
          : 'Until this is connected, ratings stay on this device only.',
    ),
    trailing: _busy
        ? const SizedBox(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_connected ? Icons.cloud_done_outlined : Icons.cloud_off),
    onTap: _busy || _connected ? null : _connect,
  );
}
