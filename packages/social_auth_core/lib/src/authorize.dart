import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'pkce.dart';
import 'url.dart';

class AuthorizeRequest {
  const AuthorizeRequest({
    required this.authorizationEndpoint,
    required this.clientId,
    required this.redirectUri,
    this.callbackUri,
    this.cancelErrors = const [],
    this.scopes = const [],
    this.scopeSeparator = ' ',
    this.usePkce = true,
    this.useNonce = false,
    this.extraParams = const {},
    this.clientIdParam = 'client_id',
    this.prefersEphemeralSession = false,
  });

  final String authorizationEndpoint;
  final String clientId;

  /// Custom scheme (`myapp://callback`) or https Universal/App Link.
  final String redirectUri;

  /// URL the browser finally lands on, when it is not [redirectUri] itself.
  /// For providers that only accept https redirects: [redirectUri] is a page
  /// on your backend that forwards the query string to this app URL.
  final String? callbackUri;

  /// Provider `error` values that mean the user backed out. `access_denied`
  /// always does.
  final List<String> cancelErrors;
  final List<String> scopes;

  /// A space, as in RFC 6749. Some providers use a comma.
  final String scopeSeparator;

  /// Only disable for providers that reject PKCE.
  final bool usePkce;

  /// Sends an OpenID Connect `nonce`. Enable when requesting an `id_token`.
  final bool useNonce;

  /// Extra authorization parameters (`prompt`, `login_hint`, …).
  final Map<String, String> extraParams;
  final String clientIdParam;

  /// iOS: do not share cookies with Safari. Android: ephemeral Custom Tab
  /// when the browser supports it.
  final bool prefersEphemeralSession;
}

class AuthorizeResult {
  const AuthorizeResult({
    required this.code,
    required this.state,
    required this.redirectUri,
    required this.params,
    this.codeVerifier,
    this.nonce,
  });

  /// Authorization code to exchange at the token endpoint.
  final String code;

  /// PKCE verifier to send along with the code. Null when PKCE is off.
  final String? codeVerifier;
  final String state;

  /// Nonce the `id_token` must carry. Null unless `useNonce` is set.
  final String? nonce;
  final String redirectUri;

  /// Every parameter the provider sent back in the redirect.
  final Map<String, String> params;
}

bool _inProgress = false;

void _assertConfig(AuthorizeRequest request) {
  final missing = [
    if (request.authorizationEndpoint.isEmpty) 'authorizationEndpoint',
    if (request.clientId.isEmpty) 'clientId',
    if (request.redirectUri.isEmpty) 'redirectUri',
  ];
  if (missing.isNotEmpty) {
    throw AuthException(
      AuthErrorCode.invalidConfig,
      'Missing required option(s): ${missing.join(', ')}',
    );
  }
  if (!isSecureEndpoint(request.authorizationEndpoint)) {
    throw const AuthException(
      AuthErrorCode.invalidConfig,
      'authorizationEndpoint must be an https URL',
    );
  }
  if (schemeOf(request.redirectUri) == null) {
    throw const AuthException(
      AuthErrorCode.invalidConfig,
      'redirectUri must be an absolute URI, e.g. myapp://callback',
    );
  }
  final callbackUri = request.callbackUri;
  if (callbackUri != null && schemeOf(callbackUri) == null) {
    throw const AuthException(
      AuthErrorCode.invalidConfig,
      'callbackUri must be an absolute URI, e.g. myapp://callback',
    );
  }
}

/// Runs the OAuth 2.0 authorization code flow in the system browser and
/// returns the code. `state` is generated and verified here; nothing is stored.
Future<AuthorizeResult> authorize(AuthorizeRequest request) async {
  _assertConfig(request);
  if (_inProgress) {
    throw const AuthException(
      AuthErrorCode.invalidConfig,
      'Another sign-in is already in progress',
    );
  }

  final state = randomBase64Url(16);
  final nonce = request.useNonce ? randomBase64Url(16) : null;
  final pkce = request.usePkce ? PkcePair.generate() : null;

  final url = appendParams(request.authorizationEndpoint, {
    ...request.extraParams,
    'response_type': 'code',
    request.clientIdParam: request.clientId,
    'redirect_uri': request.redirectUri,
    'scope': request.scopes.isEmpty
        ? null
        : request.scopes.join(request.scopeSeparator),
    'state': state,
    'nonce': nonce,
    'code_challenge': pkce?.codeChallenge,
    'code_challenge_method': pkce?.codeChallengeMethod,
  });

  final callbackUri = request.callbackUri ?? request.redirectUri;
  final String redirect;
  _inProgress = true;
  try {
    redirect = await SocialAuthCorePlatform.instance.openAuthSession(
      url: url,
      callbackUrl: callbackUri,
      prefersEphemeralSession: request.prefersEphemeralSession,
    );
  } on Object catch (error) {
    throw AuthException.from(error);
  } finally {
    _inProgress = false;
  }

  if (!matchesRedirectUri(redirect, callbackUri)) {
    throw const AuthException(
      AuthErrorCode.providerError,
      'The browser returned to an unexpected redirect URI',
    );
  }

  final params = parseRedirectParams(redirect);
  // Reported before the state check: some providers omit `state` on errors,
  // and an error grants nothing.
  final error = params['error'];
  if (error != null && error.isNotEmpty) {
    final description = params['error_description'];
    throw AuthException(
      error == 'access_denied' || request.cancelErrors.contains(error)
          ? AuthErrorCode.cancelled
          : AuthErrorCode.providerError,
      description != null && description.isNotEmpty
          ? description
          : 'The provider returned "$error"',
      providerError: error,
      providerErrorDescription: description,
    );
  }
  // A code is only accepted with the state we generated: anything else did
  // not come from the request we started.
  if (params['state'] != state) {
    throw const AuthException(
      AuthErrorCode.providerError,
      'State mismatch: the response does not belong to this sign-in',
    );
  }
  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const AuthException(
      AuthErrorCode.providerError,
      'The provider did not return an authorization code',
    );
  }

  return AuthorizeResult(
    code: code,
    codeVerifier: pkce?.codeVerifier,
    state: state,
    nonce: nonce,
    redirectUri: request.redirectUri,
    params: params,
  );
}

/// Dismisses the browser of the sign-in in progress; it fails with
/// [AuthErrorCode.cancelled].
Future<void> cancelAuthorize() =>
    SocialAuthCorePlatform.instance.cancelAuthSession();
