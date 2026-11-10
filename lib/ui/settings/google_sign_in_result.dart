/// Raising the Google account chooser, and saying which of three things
/// happened.
///
/// `google_account_token` returns null for a dismissed chooser and for a
/// token request that failed (the failure is only logged), so on Android a
/// null is reported as a cancel. A platform with no AccountManager is the one
/// failure this layer can name, and it is surfaced rather than swallowed so
/// the Connect tile never does nothing visible.
///
/// The plugin call is injectable ([IdTokenFetcher]) so tests drive every
/// branch without a platform channel.
library;

import 'package:google_account_token/google_account_token.dart' as plugin;

/// Which of the three outcomes a sign-in attempt reached.
enum GoogleSignInStatus {
  /// An ID token came back.
  succeeded,

  /// The user backed out. A choice, not a failure: nothing to report.
  cancelled,

  /// Sign-in cannot work here. The user has to see this, with the reason.
  failed,
}

/// The outcome of one attempt, with the detail needed to act on a failure.
class GoogleSignInResult {
  /// A successful attempt carrying [idToken].
  const new succeeded(String this.idToken)
    : status = GoogleSignInStatus.succeeded,
      detail = null;

  /// A dismissed chooser, or a token request the plugin could not complete.
  const new cancelled()
    : status = GoogleSignInStatus.cancelled,
      idToken = null,
      detail = null;

  /// A refusal, described by [detail].
  const new failed(String this.detail)
    : status = GoogleSignInStatus.failed,
      idToken = null;

  /// What happened.
  final GoogleSignInStatus status;

  /// The Google ID token, when one was minted.
  final String? idToken;

  /// Why the attempt failed, in terms a person can act on.
  final String? detail;
}

/// Fetches a Google ID token minted for [serverClientId], or null.
typedef IdTokenFetcher = Future<String?> Function({
  required String serverClientId,
});

/// Raises the account chooser and reports what came back.
///
/// [serverClientId] must be the project's **Web** client id; an Android
/// client id yields a token Firebase rejects as an audience mismatch.
/// [tokenFetcher] replaces the plugin's platform channel in tests.
Future<GoogleSignInResult> googleSignInAttempt({
  required String serverClientId,
  IdTokenFetcher tokenFetcher = plugin.googleIdToken,
}) async {
  if (!plugin.googleAccountTokenSupported) {
    return const GoogleSignInResult.failed(
      'Google sign-in is only available on Android',
    );
  }
  final token = await tokenFetcher(serverClientId: serverClientId);
  if (token == null) {
    return const GoogleSignInResult.cancelled();
  }
  return GoogleSignInResult.succeeded(token);
}
