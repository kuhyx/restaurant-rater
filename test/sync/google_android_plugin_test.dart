import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: tapping "Connect Google account" threw `UnimplementedError`.
///
/// The sign-in drives `GoogleSignInPlatform.instance` (the platform
/// interface), whose default instance throws until a platform package
/// registers itself. On Android that package is `google_sign_in_android`; the
/// app-facing `google_sign_in` is not used (it would register the web
/// plugin), so the Android implementation must be a direct dependency or no
/// build ever registers it. A plain unit test cannot see plugin registration,
/// so this pins the dependency itself, in the manifest and in the lock.
void main() {
  test('google_sign_in_android is declared, exactly pinned and locked', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^  google_sign_in_android: \d+\.\d+\.\d+\b', multiLine: true)
          .hasMatch(pubspec),
      isTrue,
      reason: 'direct dependency with an exact pin in pubspec.yaml',
    );
    final lock = File('pubspec.lock').readAsStringSync();
    expect(
      RegExp(
        r'^  google_sign_in_android:\n    dependency: "direct main"',
        multiLine: true,
      ).hasMatch(lock),
      isTrue,
      reason: 'locked as a direct main dependency',
    );
  });
}
