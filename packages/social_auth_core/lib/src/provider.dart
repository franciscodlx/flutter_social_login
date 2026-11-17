import 'package:http/http.dart' as http;
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'authorize.dart';
import 'id_token.dart';
import 'token.dart';

/// What a provider package contributes on top of the core.
class ProviderConfig<TProfile> {
  const ProviderConfig({
    required this.id,
    required this.authorizationEndpoint,
    required this.mapProfile,
    this.tokenEndpoint,
    this.userInfoEndpoint,
    this.revocationEndpoint,
    this.issuer,
    this.defaultScopes = const [],
    this.scopeSeparator = ' ',
    this.usePkce = true,
    this.useNonce = false,
    this.clientIdParam = 'client_id',
    this.cancelErrors = const [],
    this.extraAuthParams = const {},
    this.extraTokenParams = const {},
  });

  /// Short id used in error messages, e.g. `linkedin`.
  final String id;
  final String authorizationEndpoint;

  /// Needed for `exchangeCode: true` (public clients only).
  final String? tokenEndpoint;
  final String? userInfoEndpoint;
  final String? revocationEndpoint;

  /// Expected `iss` of the id_token, for OpenID Connect providers.
  final String? issuer;
  final List<String> defaultScopes;
  final String scopeSeparator;
  final bool usePkce;

  /// Send and verify an OpenID Connect nonce.
  final bool useNonce;
  final String clientIdParam;

  /// Provider `error` values that mean the user backed out (besides
  /// `access_denied`).
  final List<String> cancelErrors;
  final Map<String, String> extraAuthParams;
  final Map<String, String> extraTokenParams;

  /// Maps the userinfo response (or the id_token claims) to a typed profile.
  final TProfile Function(Map<String, dynamic> raw) mapProfile;

  ProviderConfig<TProfile> copyWith({
    String? authorizationEndpoint,
    String? tokenEndpoint,
    String? userInfoEndpoint,
    String? revocationEndpoint,
    String? issuer,
    List<String>? defaultScopes,
    bool? usePkce,
    bool? useNonce,
    Map<String, String>? extraAuthParams,
    Map<String, String>? extraTokenParams,
  }) => ProviderConfig<TProfile>(
    id: id,
    authorizationEndpoint: authorizationEndpoint ?? this.authorizationEndpoint,
    mapProfile: mapProfile,
    tokenEndpoint: tokenEndpoint ?? this.tokenEndpoint,
    userInfoEndpoint: userInfoEndpoint ?? this.userInfoEndpoint,
    revocationEndpoint: revocationEndpoint ?? this.revocationEndpoint,
    issuer: issuer ?? this.issuer,
    defaultScopes: defaultScopes ?? this.defaultScopes,
    scopeSeparator: scopeSeparator,
    usePkce: usePkce ?? this.usePkce,
    useNonce: useNonce ?? this.useNonce,
    clientIdParam: clientIdParam,
    cancelErrors: cancelErrors,
    extraAuthParams: extraAuthParams ?? this.extraAuthParams,
    extraTokenParams: extraTokenParams ?? this.extraTokenParams,
  );
}

class SignInOptions {
  const SignInOptions({
    required this.clientId,
    required this.redirectUri,
    this.callbackUri,
    this.scopes,
    this.extraParams = const {},
    this.prefersEphemeralSession = false,
    this.exchangeCode = false,
  });

  final String clientId;
  final String redirectUri;

  /// App URL the browser lands on when [redirectUri] is a forwarding page on
  /// your backend.
  final String? callbackUri;

  /// Overrides the provider's default scopes.
  final List<String>? scopes;
  final Map<String, String> extraParams;
  final bool prefersEphemeralSession;

  /// Exchange the code on-device as a public client (PKCE, no secret) and
  /// load the profile. Leave false when your backend does the exchange.
  final bool exchangeCode;

  SignInOptions copyWith({
    List<String>? scopes,
    Map<String, String>? extraParams,
    bool? prefersEphemeralSession,
    bool? exchangeCode,
  }) => SignInOptions(
    clientId: clientId,
    redirectUri: redirectUri,
    callbackUri: callbackUri,
    scopes: scopes ?? this.scopes,
    extraParams: extraParams ?? this.extraParams,
    prefersEphemeralSession:
        prefersEphemeralSession ?? this.prefersEphemeralSession,
    exchangeCode: exchangeCode ?? this.exchangeCode,
  );
}

class SignInResult<TProfile> {
  const SignInResult({
    required this.authorization,
    this.tokens,
    this.idTokenClaims,
    this.profile,
  });

  /// What came back from the browser.
  final AuthorizeResult authorization;

  /// Only with `exchangeCode: true`.
  final TokenResponse? tokens;

  /// Unverified id_token claims (signature is checked on your backend).
  final Map<String, dynamic>? idTokenClaims;
  final TProfile? profile;

  String get code => authorization.code;
  String? get codeVerifier => authorization.codeVerifier;
  String get state => authorization.state;
  String? get nonce => authorization.nonce;
  String get redirectUri => authorization.redirectUri;
  Map<String, String> get params => authorization.params;
  String? get accessToken => tokens?.accessToken;
  String? get refreshToken => tokens?.refreshToken;
  String? get idToken => tokens?.idToken;
  int? get expiresIn => tokens?.expiresIn;
}

/// The API every plugin of the family exposes.
class ProviderLogin<TProfile> {
  ProviderLogin(this.provider, {this.httpClient});

  final ProviderConfig<TProfile> provider;

  /// HTTP client for the token and userinfo calls; a new one per call when null.
  final http.Client? httpClient;

  Future<bool> isAvailable() => SocialAuthCorePlatform.instance.isAvailable();

  Future<SignInResult<TProfile>> signIn(SignInOptions options) async {
    final tokenEndpoint = provider.tokenEndpoint;
    if (options.exchangeCode && tokenEndpoint == null) {
      throw AuthException(
        AuthErrorCode.invalidConfig,
        '${provider.id} cannot exchange the code on-device; do it from your backend',
      );
    }

    final authorization = await authorize(
      AuthorizeRequest(
        authorizationEndpoint: provider.authorizationEndpoint,
        clientId: options.clientId,
        redirectUri: options.redirectUri,
        callbackUri: options.callbackUri,
        cancelErrors: provider.cancelErrors,
        scopes: options.scopes ?? provider.defaultScopes,
        scopeSeparator: provider.scopeSeparator,
        usePkce: provider.usePkce,
        useNonce: provider.useNonce,
        clientIdParam: provider.clientIdParam,
        extraParams: {...provider.extraAuthParams, ...options.extraParams},
        prefersEphemeralSession: options.prefersEphemeralSession,
      ),
    );

    if (!options.exchangeCode || tokenEndpoint == null) {
      return SignInResult(authorization: authorization);
    }

    final tokens = await exchangeCode(
      tokenEndpoint: tokenEndpoint,
      clientId: options.clientId,
      code: authorization.code,
      redirectUri: authorization.redirectUri,
      codeVerifier: authorization.codeVerifier,
      clientIdParam: provider.clientIdParam,
      extraParams: provider.extraTokenParams,
      client: httpClient,
    );

    Map<String, dynamic>? idTokenClaims;
    final idToken = tokens.idToken;
    if (idToken != null) {
      idTokenClaims = decodeIdToken(idToken);
      validateIdTokenClaims(
        idTokenClaims,
        issuer: provider.issuer,
        audience: options.clientId,
        nonce: authorization.nonce,
      );
    }

    TProfile? profile;
    final userInfoEndpoint = provider.userInfoEndpoint;
    final accessToken = tokens.accessToken;
    if (userInfoEndpoint != null && accessToken != null) {
      profile = provider.mapProfile(
        await fetchUserInfo(userInfoEndpoint, accessToken, client: httpClient),
      );
    } else if (idTokenClaims != null) {
      profile = provider.mapProfile(idTokenClaims);
    }

    return SignInResult(
      authorization: authorization,
      tokens: tokens,
      idTokenClaims: idTokenClaims,
      profile: profile,
    );
  }

  /// The core keeps no session, so signing out only means revoking [token] at
  /// the provider when it has a revocation endpoint. Clearing your own stored
  /// tokens is up to the app.
  Future<void> signOut({
    String? clientId,
    String? token,
    String? tokenTypeHint,
  }) async {
    final endpoint = provider.revocationEndpoint;
    if (endpoint != null && token != null && clientId != null) {
      await revokeToken(
        revocationEndpoint: endpoint,
        clientId: clientId,
        token: token,
        tokenTypeHint: tokenTypeHint,
        client: httpClient,
      );
    }
  }
}
