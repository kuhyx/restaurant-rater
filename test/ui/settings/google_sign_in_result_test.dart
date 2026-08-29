import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';

import 'fake_google_sign_in.dart';

/// Covers the classification that the shared library cannot do.
///
/// `crdt_sync_flutter`'s `googleIdToken` collapses every plugin exception into
/// null, so "you dismissed the picker" and "your OAuth client is not
/// registered" arrive identically. These tests pin the distinction, because
/// losing it is what made the Connect tile do nothing visible on-device.
void main() {
  test('falls back to the registered platform instance', () async {
    // No `platform:` argument: this is the production path, which reads
    // GoogleSignInPlatform.instance. Settable, so the default is covered for
    // real rather than suppressed.
    final google = FakeGoogleSignIn(result: googleResult('from-the-instance'));
    GoogleSignInPlatform.instance = google;

    final attempt = await googleSignInAttempt(serverClientId: 'web-client');

    expect(attempt.status, GoogleSignInStatus.succeeded);
    expect(attempt.idToken, 'from-the-instance');
  });

  test('a minted token succeeds', () async {
    final google = FakeGoogleSignIn(result: googleResult('an-id-token'));

    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: google,
    );

    expect(attempt.status, GoogleSignInStatus.succeeded);
    expect(attempt.idToken, 'an-id-token');
    // The Web client id, not an Android one: Firebase rejects a token minted
    // for an Android client as an audience mismatch.
    expect(google.initialisedWith, 'web-client');
  });

  test('a bare cancel is a choice, not a failure', () async {
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      ),
    );

    expect(attempt.status, GoogleSignInStatus.cancelled);
    expect(attempt.detail, isNull);
  });

  test('a cancel carrying a description is reported', () async {
    // The failure mode this narrowness exists for: on Android's Credential
    // Manager an unregistered client can arrive shaped like a cancel, so the
    // code alone must not be trusted to mean "the user changed their mind".
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'UNREGISTERED_ON_API_CONSOLE',
        ),
      ),
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('UNREGISTERED_ON_API_CONSOLE'));
  });

  test('a cancel carrying details is reported', () async {
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          details: 'status=UNREGISTERED_ON_API_CONSOLE',
        ),
      ),
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('status=UNREGISTERED_ON_API_CONSOLE'));
  });

  test('a configuration error names the code and the reason', () async {
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'unregistered SHA-1',
        ),
      ),
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('clientConfigurationError'));
    expect(attempt.detail, contains('unregistered SHA-1'));
  });

  test('an exception from init is classified too', () async {
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(
        initError: const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
          description: 'no Play services',
        ),
      ),
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('no Play services'));
  });

  test('a platform with no sign-in flow fails loudly', () async {
    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      platform: FakeGoogleSignIn(canAuthenticate: false),
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('no Google sign-in flow'));
  });

  test(
    'an account with no ID token fails rather than silently passing',
    () async {
      final attempt = await googleSignInAttempt(
        serverClientId: 'web-client',
        platform: FakeGoogleSignIn(result: googleResult(null)),
      );

      expect(attempt.status, GoogleSignInStatus.failed);
      expect(attempt.detail, contains('no ID token'));
    },
  );
}
