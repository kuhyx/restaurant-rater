import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: the Android APK must not link play-services-auth, googleid or
/// Credential Manager.
///
/// Sign-in goes through `google_account_token` (AccountManager). The
/// `google_sign_in*` packages are what pull those SDKs in, so this pins the
/// plugin as a direct dependency and the old packages as absent, in the
/// manifest and in the lock. A unit test cannot see plugin registration.
void main() {
  test(
    'google_account_token is declared and locked, google_sign_in is gone',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(
          r'^  google_account_token:\n    git:\n(?:      .*\n)*?'
          r'      ref: google_account_token-v\d+\.\d+\.\d+\n',
          multiLine: true,
        ).hasMatch(pubspec),
        isTrue,
        reason: 'direct git dependency with a tag ref in pubspec.yaml',
      );
      final lock = File('pubspec.lock').readAsStringSync();
      expect(
        RegExp(
          r'^  google_account_token:\n    dependency: "direct main"',
          multiLine: true,
        ).hasMatch(lock),
        isTrue,
        reason: 'locked as a direct main dependency',
      );
      expect(
        RegExp(r'^  google_sign_in', multiLine: true).hasMatch(lock),
        isFalse,
        reason: 'no google_sign_in* package may be locked',
      );
    },
  );
}
