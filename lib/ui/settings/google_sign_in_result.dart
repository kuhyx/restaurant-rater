/// Raising the Google picker, and saying which of three things happened.
///
/// This exists because the shared library cannot answer the question. Its
/// `googleIdToken` collapses every `GoogleSignInException` into null, so a
/// dismissed picker and an OAuth client Google has never heard of arrive at
/// the caller as the same value -- which is exactly how tapping "Connect"
/// came to do nothing visible on a device whose client was unregistered.
///
/// The plugin is driven through [GoogleSignInPlatform] rather than the
/// `GoogleSignIn` facade so that the failure branches are reachable from
/// `flutter test`: the platform instance is settable, the facade's channel is
/// not. That keeps this file honestly covered instead of suppressed.
library;

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// Which of the three outcomes a sign-in attempt reached.
enum GoogleSignInStatus {
  /// An ID token came back.
  succeeded,

  /// The user backed out. A choice, not a failure: nothing to report.
  cancelled,

  /// Google refused. The user has to see this, with the reason.
  failed,
}

/// The outcome of one attempt, with the detail needed to act on a failure.
class GoogleSignInResult {
  /// A successful attempt carrying [idToken].
  const GoogleSignInResult.succeeded(String this.idToken)
    : status = GoogleSignInStatus.succeeded,
      detail = null;

  /// A user-dismissed picker.
  const GoogleSignInResult.cancelled()
    : status = GoogleSignInStatus.cancelled,
      idToken = null,
      detail = null;

  /// A refusal, described by [detail].
  const GoogleSignInResult.failed(String this.detail)
    : status = GoogleSignInStatus.failed,
      idToken = null;

  /// What happened.
  final GoogleSignInStatus status;

  /// The Google ID token, when one was minted.
  final String? idToken;

  /// Why the attempt failed, in terms a person can act on.
  final String? detail;
}

/// Turns a plugin exception into one of the three outcomes.
///
/// Only [GoogleSignInExceptionCode.canceled] with nothing attached counts as a
/// cancel. That narrowness is deliberate and was the second half of this bug:
/// on Android's Credential Manager an unregistered client can surface as a
/// cancel-shaped code, so treating the code alone as "the user changed their
/// mind" would hide the misconfiguration all over again. Anything carrying a
/// description or details is Google explaining a refusal, and is reported.
GoogleSignInResult classifyGoogleFailure(GoogleSignInException error) {
  final described = error.description ?? '';
  if (error.code == GoogleSignInExceptionCode.canceled &&
      described.isEmpty &&
      error.details == null) {
    return const GoogleSignInResult.cancelled();
  }
  final details = error.details == null ? '' : ' (${error.details})';
  return GoogleSignInResult.failed('${error.code.name}: $described$details');
}

/// Raises the account picker and reports what came back.
///
/// [serverClientId] must be the project's **Web** client id; Android has to
/// request a token minted for it, and an Android client id yields a token
/// Firebase rejects as an audience mismatch.
Future<GoogleSignInResult> googleSignInAttempt({
  required String serverClientId,
  GoogleSignInPlatform? platform,
}) async {
  final google = platform ?? GoogleSignInPlatform.instance;
  try {
    await google.init(InitParameters(serverClientId: serverClientId));
    if (!google.supportsAuthenticate()) {
      return const GoogleSignInResult.failed(
        'this build of Android has no Google sign-in flow available',
      );
    }
    final results = await google.authenticate(const AuthenticateParameters());
    final token = results.authenticationTokens.idToken;
    if (token == null) {
      // Signed in, but with no ID token there is nothing to hand Firebase.
      return const GoogleSignInResult.failed(
        'Google returned an account but no ID token',
      );
    }
    return GoogleSignInResult.succeeded(token);
  } on GoogleSignInException catch (error) {
    return classifyGoogleFailure(error);
  }
}
