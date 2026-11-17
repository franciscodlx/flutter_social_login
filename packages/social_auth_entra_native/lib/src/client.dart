import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

import 'errors.dart';
import 'steps.dart';

typedef _Form = Map<String, String?>;
typedef _Body = Map<String, dynamic>;

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int? _int(Object? value) => value is num ? value.toInt() : null;

const _startPath = {
  EntraFlow.signIn: '/oauth2/v2.0/initiate',
  EntraFlow.signUp: '/signup/v1.0/start',
  EntraFlow.resetPassword: '/resetpassword/v1.0/start',
};
const _challengePath = {
  EntraFlow.signIn: '/oauth2/v2.0/challenge',
  EntraFlow.signUp: '/signup/v1.0/challenge',
  EntraFlow.resetPassword: '/resetpassword/v1.0/challenge',
};

// Every request must offer `redirect`: it is how Entra says "use the
// browser".
String _challengeTypes({required bool withPassword}) =>
    withPassword ? 'oob password redirect' : 'oob redirect';

/// Microsoft Entra External ID native authentication: sign-in, sign-up and
/// password reset with your own screens, through Entra's HTTP API (no
/// browser), plus the browser flow as fallback.
class EntraNativeAuth {
  /// [tenantSubdomain] is `contoso` for the external tenant
  /// `contoso.onmicrosoft.com`; [clientId] is the application (client) ID.
  /// [scopes] defaults to `openid offline_access` (id_token + refresh
  /// token). [baseUrl] replaces
  /// `https://{tenant}.ciamlogin.com/{tenant}.onmicrosoft.com`, e.g. to point
  /// at a test server. [pollTimeout] bounds how long `submitNewPassword`
  /// waits for the reset to complete.
  factory EntraNativeAuth({
    required String tenantSubdomain,
    required String clientId,
    List<String> scopes = const ['openid', 'offline_access'],
    String? baseUrl,
    Duration pollTimeout = const Duration(seconds: 30),
    http.Client? httpClient,
  }) {
    if (clientId.isEmpty || (tenantSubdomain.isEmpty && baseUrl == null)) {
      throw const AuthException(
        AuthErrorCode.invalidConfig,
        'tenantSubdomain and clientId are required',
      );
    }
    final base =
        baseUrl ??
        'https://$tenantSubdomain.ciamlogin.com/$tenantSubdomain.onmicrosoft.com';
    return EntraNativeAuth._(
      baseUrl: base.replaceFirst(RegExp(r'/+$'), ''),
      clientId: clientId,
      scope: scopes.join(' '),
      pollTimeout: pollTimeout,
      httpClient: httpClient,
    );
  }

  EntraNativeAuth._({
    required this.baseUrl,
    required this.clientId,
    required this.scope,
    required this.pollTimeout,
    this.httpClient,
  });

  final String baseUrl;
  final String clientId;
  final String scope;
  final Duration pollTimeout;
  final http.Client? httpClient;

  /// Email + password when [password] is given, email one-time passcode
  /// otherwise.
  Future<EntraStep> signIn({required String username, String? password}) async {
    final types = password != null ? 'password redirect' : 'oob redirect';
    final started = await _call(_startPath[EntraFlow.signIn]!, {
      'username': username,
      'challenge_type': types,
    });
    if (_isRedirect(started)) {
      return BrowserRequiredStep(flow: EntraFlow.signIn, username: username);
    }
    final step = await _challenge(
      EntraFlow.signIn,
      username,
      _token(started),
      types,
    );
    return step is PasswordRequiredStep && password != null
        ? _signInWithPassword(step, password)
        : step;
  }

  /// Omit [password] for tenants that use email one-time passcode.
  /// [attributes] are keyed by their programmable name, e.g.
  /// `{'displayName': …, 'city': …}`.
  Future<EntraStep> signUp({
    required String username,
    String? password,
    Map<String, String>? attributes,
  }) async {
    final types = _challengeTypes(withPassword: password != null);
    final started = await _call(_startPath[EntraFlow.signUp]!, {
      'username': username,
      'password': password,
      'attributes': attributes == null ? null : jsonEncode(attributes),
      'challenge_type': types,
    });
    return _isRedirect(started)
        ? BrowserRequiredStep(flow: EntraFlow.signUp, username: username)
        : _challenge(EntraFlow.signUp, username, _token(started), types);
  }

  /// Self-service password reset (email + password accounts).
  Future<EntraStep> resetPassword({required String username}) async {
    final started = await _call(_startPath[EntraFlow.resetPassword]!, {
      'username': username,
      'challenge_type': 'oob redirect',
    });
    return _isRedirect(started)
        ? BrowserRequiredStep(flow: EntraFlow.resetPassword, username: username)
        : _challenge(
            EntraFlow.resetPassword,
            username,
            _token(started),
            'oob redirect',
          );
  }

  Future<EntraStep> submitCode(CodeRequiredStep step, String code) async {
    final form = {
      'continuation_token': step.continuationToken,
      'grant_type': 'oob',
      'oob': code,
    };
    switch (step.flow) {
      case EntraFlow.signIn:
        return _requestToken({...form, 'username': step.username});
      case EntraFlow.signUp:
        return _continueSignUp(step.username, form);
      case EntraFlow.resetPassword:
        final body = await _call('/resetpassword/v1.0/continue', form);
        return _isRedirect(body)
            ? BrowserRequiredStep(
                flow: EntraFlow.resetPassword,
                username: step.username,
              )
            : NewPasswordRequiredStep(
                username: step.username,
                continuationToken: _token(body),
              );
    }
  }

  /// Sends a new code for the same step.
  Future<EntraStep> resendCode(CodeRequiredStep step) => _challenge(
    step.flow,
    step.username,
    step.continuationToken,
    step.flow == EntraFlow.signUp
        ? _challengeTypes(withPassword: true)
        : 'oob redirect',
  );

  Future<EntraStep> submitPassword(
    PasswordRequiredStep step,
    String password,
  ) => step.flow == EntraFlow.signUp
      ? _continueSignUp(step.username, {
          'continuation_token': step.continuationToken,
          'grant_type': 'password',
          'password': password,
        })
      : _signInWithPassword(step, password);

  Future<EntraStep> submitAttributes(
    AttributesRequiredStep step,
    Map<String, String> attributes,
  ) => _continueSignUp(step.username, {
    'continuation_token': step.continuationToken,
    'grant_type': 'attributes',
    'attributes': jsonEncode(attributes),
  });

  /// Sets the new password, waits for the reset and signs the user in.
  Future<EntraStep> submitNewPassword(
    NewPasswordRequiredStep step,
    String newPassword,
  ) async {
    final submitted = await _call('/resetpassword/v1.0/submit', {
      'continuation_token': step.continuationToken,
      'new_password': newPassword,
    });
    var continuationToken = _token(submitted);
    final interval = Duration(seconds: _int(submitted['poll_interval']) ?? 2);
    final deadline = DateTime.now().add(pollTimeout);
    for (;;) {
      final polled = await _call('/resetpassword/v1.0/poll_completion', {
        'continuation_token': continuationToken,
      });
      continuationToken =
          _text(polled['continuation_token']) ?? continuationToken;
      if (polled['status'] == 'succeeded') {
        return _finish(step.username, continuationToken);
      }
      if (polled['status'] == 'failed') {
        throw const AuthException(
          AuthErrorCode.providerError,
          'The password reset failed',
        );
      }
      if (DateTime.now().add(interval).isAfter(deadline)) {
        throw const AuthException(
          AuthErrorCode.providerError,
          'The password reset is taking too long; ask the user to sign in '
          'with the new password',
        );
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<EntraTokens> refresh(String refreshToken) async => _toTokens(
    await _call('/oauth2/v2.0/token', {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': scope,
    }),
  );

  /// Web fallback: the standard browser flow (authorization code + PKCE)
  /// against the same tenant. [redirectUri] must be registered for the app,
  /// e.g. `miapp://callback`; [loginHint] pre-fills the account.
  Future<EntraTokens> signInWithBrowser({
    required String redirectUri,
    String? loginHint,
    bool prefersEphemeralSession = false,
  }) async {
    final login = ProviderLogin<Map<String, dynamic>>(
      ProviderConfig(
        id: 'entra',
        authorizationEndpoint: '$baseUrl/oauth2/v2.0/authorize',
        tokenEndpoint: '$baseUrl/oauth2/v2.0/token',
        defaultScopes: scope.split(' '),
        useNonce: true,
        mapProfile: (raw) => raw,
      ),
      httpClient: httpClient,
    );
    final result = await login.signIn(
      SignInOptions(
        clientId: clientId,
        redirectUri: redirectUri,
        prefersEphemeralSession: prefersEphemeralSession,
        extraParams: {'login_hint': ?loginHint},
        exchangeCode: true,
      ),
    );
    return _toTokens(result.tokens?.raw ?? const {});
  }

  // ---------------------------------------------------------------------

  /// POSTs a form. API errors come back with `ok: false`.
  Future<({bool ok, int status, _Body body})> _post(
    String path,
    _Form form,
  ) async {
    final client = httpClient ?? http.Client();
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Accept': 'application/json'},
        // A Map body is sent as application/x-www-form-urlencoded.
        body: {
          'client_id': clientId,
          for (final entry in form.entries)
            if (entry.value != null) entry.key: entry.value!,
        },
      );
    } on Exception catch (error) {
      throw AuthException(
        AuthErrorCode.network,
        'Could not reach Microsoft Entra',
        cause: error,
      );
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
    _Body body = {};
    try {
      final parsed = jsonDecode(utf8.decode(response.bodyBytes));
      if (parsed is Map<String, dynamic>) {
        body = parsed;
      }
    } on FormatException {
      // Non-JSON body: reported through the status.
    }
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['error'] == null;
    return (ok: ok, status: response.statusCode, body: body);
  }

  Never _fail(int status, _Body body) {
    final error = body['error'];
    throw EntraAuthException(
      error == 'invalid_client' || error == 'unauthorized_client'
          ? AuthErrorCode.invalidConfig
          : AuthErrorCode.providerError,
      _text(body['error_description']) ??
          (error != null
              ? 'Microsoft Entra returned "$error"'
              : 'Request failed with status $status'),
      body: body,
      status: status,
    );
  }

  Future<_Body> _call(String path, _Form form) async {
    final response = await _post(path, form);
    return response.ok ? response.body : _fail(response.status, response.body);
  }

  bool _isRedirect(_Body body) => body['challenge_type'] == 'redirect';

  String _token(_Body body) =>
      _text(body['continuation_token']) ??
      (throw const AuthException(
        AuthErrorCode.providerError,
        'Microsoft Entra did not return a continuation token',
      ));

  EntraTokens _toTokens(_Body body) {
    final accessToken = _text(body['access_token']);
    if (accessToken == null) {
      throw const AuthException(
        AuthErrorCode.providerError,
        'Microsoft Entra did not return an access token',
      );
    }
    final idToken = _text(body['id_token']);
    Map<String, dynamic>? claims;
    EntraProfile? profile;
    if (idToken != null) {
      claims = decodeIdToken(idToken);
      validateIdTokenClaims(claims, audience: clientId);
      profile = EntraProfile(
        id: '${claims['oid'] ?? claims['sub'] ?? ''}',
        email: _text(claims['email']) ?? _text(claims['preferred_username']),
        name: _text(claims['name']),
      );
    }
    return EntraTokens(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: _text(body['refresh_token']),
      expiresIn: _int(body['expires_in']),
      scope: _text(body['scope']),
      idTokenClaims: claims,
      profile: profile,
    );
  }

  Future<SignedInStep> _requestToken(_Form form) async => SignedInStep(
    _toTokens(await _call('/oauth2/v2.0/token', {...form, 'scope': scope})),
  );

  /// Asks Entra which credential comes next and turns the answer into a step.
  Future<EntraStep> _challenge(
    EntraFlow flow,
    String username,
    String continuationToken,
    String challengeType,
  ) async {
    final body = await _call(_challengePath[flow]!, {
      'continuation_token': continuationToken,
      'challenge_type': challengeType,
    });
    if (_isRedirect(body)) {
      return BrowserRequiredStep(flow: flow, username: username);
    }
    if (body['challenge_type'] == 'password') {
      return PasswordRequiredStep(
        flow: flow,
        username: username,
        continuationToken: _token(body),
      );
    }
    return CodeRequiredStep(
      flow: flow,
      username: username,
      continuationToken: _token(body),
      channel: _text(body['challenge_channel']),
      sentTo: _text(body['challenge_target_label']),
      codeLength: _int(body['code_length']),
    );
  }

  Future<SignedInStep> _signInWithPassword(
    EntraContinuation step,
    String password,
  ) => _requestToken({
    'continuation_token': step.continuationToken,
    'grant_type': 'password',
    'password': password,
    'username': step.username,
  });

  /// After sign-up or password reset: the last continuation token becomes
  /// tokens.
  Future<SignedInStep> _finish(String username, String continuationToken) =>
      _requestToken({
        'continuation_token': continuationToken,
        'grant_type': 'continuation_token',
        'username': username,
      });

  /// `/signup/v1.0/continue`: Entra may still ask for a password or
  /// attributes.
  Future<EntraStep> _continueSignUp(String username, _Form form) async {
    final response = await _post('/signup/v1.0/continue', form);
    final body = response.body;
    if (response.ok) {
      return _isRedirect(body)
          ? BrowserRequiredStep(flow: EntraFlow.signUp, username: username)
          : _finish(username, _token(body));
    }
    final continuationToken = _text(body['continuation_token']);
    if (body['error'] == 'credential_required' && continuationToken != null) {
      // Entra says which credential through a new challenge.
      return _challenge(
        EntraFlow.signUp,
        username,
        continuationToken,
        _challengeTypes(withPassword: true),
      );
    }
    if (body['error'] == 'attributes_required' && continuationToken != null) {
      return AttributesRequiredStep(
        username: username,
        continuationToken: continuationToken,
        requiredAttributes: [
          for (final attribute in body['required_attributes'] as List? ?? [])
            if (attribute is Map<String, dynamic>)
              RequiredAttribute.fromJson(attribute),
        ],
      );
    }
    return _fail(response.status, body);
  }
}
