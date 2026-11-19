import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

class TokenResponse {
  const TokenResponse({
    required this.raw,
    this.accessToken,
    this.tokenType,
    this.expiresIn,
    this.refreshToken,
    this.idToken,
    this.scope,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> raw) => TokenResponse(
    accessToken: _string(raw['access_token']),
    tokenType: _string(raw['token_type']),
    expiresIn: _int(raw['expires_in']),
    refreshToken: _string(raw['refresh_token']),
    idToken: _string(raw['id_token']),
    scope: _string(raw['scope']),
    raw: raw,
  );

  final String? accessToken;
  final String? tokenType;

  /// Lifetime of the access token in seconds.
  final int? expiresIn;
  final String? refreshToken;
  final String? idToken;
  final String? scope;

  /// Response body exactly as the provider sent it.
  final Map<String, dynamic> raw;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text),
  _ => null,
};

/// Sends [request] and returns its JSON object, mapping transport failures to
/// [AuthErrorCode.network] and provider errors to [AuthErrorCode.providerError].
Future<Map<String, dynamic>> _send(
  Future<http.Response> Function(http.Client client) request,
  Uri url,
  http.Client? client,
) async {
  final owned = client == null;
  final effective = client ?? http.Client();
  final http.Response response;
  try {
    response = await request(effective);
  } on Object catch (error) {
    throw AuthException(
      AuthErrorCode.network,
      'Could not reach $url',
      cause: error,
    );
  } finally {
    if (owned) {
      effective.close();
    }
  }

  var body = <String, dynamic>{};
  try {
    final parsed = jsonDecode(utf8.decode(response.bodyBytes));
    if (parsed is Map<String, dynamic>) {
      body = parsed;
    }
  } on Object {
    // Non-JSON body: reported through the status below.
  }

  final ok = response.statusCode >= 200 && response.statusCode < 300;
  if (!ok || body['error'] is String) {
    // OAuth errors use `error`/`error_description`; REST APIs such as X's
    // return problem details (`title`, `detail`, `reason`) instead.
    final providerError = _string(body['error']) ?? _string(body['reason']);
    final description =
        _string(body['error_description']) ??
        _string(body['message']) ??
        _string(body['detail']) ??
        _string(body['title']);
    throw AuthException(
      AuthErrorCode.providerError,
      description ??
          (providerError != null
              ? 'The provider returned "$providerError"'
              : 'Request failed with status ${response.statusCode}'),
      providerError: providerError,
      providerErrorDescription: description,
      status: response.statusCode,
    );
  }
  return body;
}

Future<Map<String, dynamic>> _postForm(
  String endpoint,
  Map<String, String?> form, {
  Map<String, String> headers = const {},
  http.Client? client,
}) {
  final url = Uri.parse(endpoint);
  return _send(
    (c) => c.post(
      url,
      headers: {'Accept': 'application/json', ...headers},
      // A Map body is sent as application/x-www-form-urlencoded.
      body: {
        for (final entry in form.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
    ),
    url,
    client,
  );
}

/// Exchanges the code as a **public client** (PKCE, no client secret).
/// If the provider requires a secret, do this from your backend instead.
Future<TokenResponse> exchangeCode({
  required String tokenEndpoint,
  required String clientId,
  required String code,
  required String redirectUri,
  String? codeVerifier,
  Map<String, String> extraParams = const {},
  String clientIdParam = 'client_id',
  Map<String, String> headers = const {},
  http.Client? client,
}) async => TokenResponse.fromJson(
  await _postForm(
    tokenEndpoint,
    {
      ...extraParams,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      clientIdParam: clientId,
      'code_verifier': codeVerifier,
    },
    headers: headers,
    client: client,
  ),
);

/// Refreshes an access token as a public client.
Future<TokenResponse> refreshAccessToken({
  required String tokenEndpoint,
  required String clientId,
  required String refreshToken,
  List<String> scopes = const [],
  Map<String, String> extraParams = const {},
  String clientIdParam = 'client_id',
  Map<String, String> headers = const {},
  http.Client? client,
}) async => TokenResponse.fromJson(
  await _postForm(
    tokenEndpoint,
    {
      ...extraParams,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      clientIdParam: clientId,
      'scope': scopes.isEmpty ? null : scopes.join(' '),
    },
    headers: headers,
    client: client,
  ),
);

/// Revokes a token (RFC 7009) as a public client.
Future<void> revokeToken({
  required String revocationEndpoint,
  required String clientId,
  required String token,
  String? tokenTypeHint,
  http.Client? client,
}) async {
  await _postForm(revocationEndpoint, {
    'token': token,
    'token_type_hint': tokenTypeHint,
    'client_id': clientId,
  }, client: client);
}

/// GETs a userinfo-style endpoint with a bearer token.
Future<Map<String, dynamic>> fetchUserInfo(
  String userInfoEndpoint,
  String accessToken, {
  Map<String, String> headers = const {},
  http.Client? client,
}) {
  final url = Uri.parse(userInfoEndpoint);
  return _send(
    (c) => c.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
        ...headers,
      },
    ),
    url,
    client,
  );
}
