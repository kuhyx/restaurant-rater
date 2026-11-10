import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/ui/settings/google_sign_in_result.dart';

const _channel = MethodChannel('dev.kuhy/google_account_token');

/// The plugin returns null for a dismissed chooser and for a failed token
/// request alike, so on Android null is a cancel; off Android the failure is
/// named so the Connect tile is never silent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a minted token succeeds with the Web client id', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    String? asked;

    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      tokenFetcher: ({required serverClientId}) async {
        asked = serverClientId;
        return 'an-id-token';
      },
    );

    expect(attempt.status, GoogleSignInStatus.succeeded);
    expect(attempt.idToken, 'an-id-token');
    // The Web client id, not an Android one: Firebase rejects a token minted
    // for an Android client as an audience mismatch.
    expect(asked, 'web-client');
  });

  test('no token on Android is a cancel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      tokenFetcher: ({required serverClientId}) async => null,
    );

    expect(attempt.status, GoogleSignInStatus.cancelled);
    expect(attempt.detail, isNull);
  });

  test('a platform without AccountManager fails loudly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final attempt = await googleSignInAttempt(
      serverClientId: 'web-client',
      tokenFetcher: ({required serverClientId}) async => 'unreachable',
    );

    expect(attempt.status, GoogleSignInStatus.failed);
    expect(attempt.detail, contains('only available on Android'));
  });

  test('defaults to the account-token plugin channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    Object? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          sent = call.arguments;
          return 'plugin-token';
        });

    final attempt = await googleSignInAttempt(serverClientId: 'web-client');

    expect(attempt.status, GoogleSignInStatus.succeeded);
    expect(attempt.idToken, 'plugin-token');
    expect(sent, {'serverClientId': 'web-client'});
  });
}
