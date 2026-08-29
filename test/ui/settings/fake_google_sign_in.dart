import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// A hand-written `GoogleSignInPlatform` standing in for the account picker.
///
/// The point of driving the platform interface rather than the `GoogleSignIn`
/// facade: this class makes every refusal branch reachable from
/// `flutter test`, so the code that classifies them is covered rather than
/// suppressed. Only the four members the sign-in path calls are implemented;
/// the rest of the interface throws, which is honest -- reaching one would be
/// a bug in the caller, not a case to fake.
class FakeGoogleSignIn extends GoogleSignInPlatform {
  /// Creates a fake that answers `authenticate` with [result], or throws
  /// [error] when one is given.
  FakeGoogleSignIn({
    this.result,
    this.error,
    this.canAuthenticate = true,
    this.initError,
  });

  /// What `authenticate` returns when it is not throwing.
  final AuthenticationResults? result;

  /// Thrown from `authenticate` instead of returning.
  final GoogleSignInException? error;

  /// Thrown from `init`, standing in for a misconfigured client id.
  final GoogleSignInException? initError;

  /// What `supportsAuthenticate` reports.
  final bool canAuthenticate;

  /// The server client id `init` was given, for asserting the Web id is used.
  String? initialisedWith;

  @override
  Future<void> init(InitParameters params) async {
    initialisedWith = params.serverClientId;
    if (initError != null) {
      throw initError!;
    }
  }

  @override
  bool supportsAuthenticate() => canAuthenticate;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (error != null) {
      throw error!;
    }
    return result!;
  }

  // The sign-in path never reaches any of these. Throwing beats returning a
  // plausible-looking value: a silent stub would let a future caller take a
  // branch this fake has no opinion about.
  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => throw UnimplementedError();

  @override
  bool authorizationRequiresUserInteraction() => throw UnimplementedError();

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) => throw UnimplementedError();

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) => throw UnimplementedError();

  @override
  Future<void> signOut(SignOutParams params) => throw UnimplementedError();

  @override
  Future<void> disconnect(DisconnectParams params) =>
      throw UnimplementedError();
}

/// A successful result carrying [idToken], or none when null.
AuthenticationResults googleResult(String? idToken) => AuthenticationResults(
  user: const GoogleSignInUserData(email: '321krzychu@gmail.com', id: 'uid'),
  authenticationTokens: AuthenticationTokenData(idToken: idToken),
);
