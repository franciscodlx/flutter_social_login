import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

const xAuthorizationEndpoint = 'https://x.com/i/oauth2/authorize';
const xTokenEndpoint = 'https://api.x.com/2/oauth2/token';
const xRevocationEndpoint = 'https://api.x.com/2/oauth2/revoke';
const xUserInfoEndpoint = 'https://api.x.com/2/users/me';

/// What `GET /2/users/me` needs. Add [xOfflineScope] for a refresh token.
const xDefaultScopes = ['users.read', 'tweet.read'];

/// Scope that makes X issue a refresh token.
const xOfflineScope = 'offline.access';

/// Scope that lets the app read the account's confirmed email.
const xEmailScope = 'users.email';

const _baseUserFields = [
  'id',
  'name',
  'username',
  'profile_image_url',
  'verified',
];

class XProfile {
  const XProfile({
    required this.id,
    required this.username,
    this.name,
    this.picture,
    this.verified,
    this.email,
  });

  /// Numeric user id, as a string.
  final String id;

  /// Handle without the `@`.
  final String username;
  final String? name;

  /// Avatar URL (X returns the 48px `_normal` variant).
  final String? picture;
  final bool? verified;

  /// Only with [xEmailScope], and only if the account has a confirmed email.
  final String? email;

  /// Maps the `GET /2/users/me` response (`{"data": {...}}`) or the bare user.
  factory XProfile.fromJson(Map<String, dynamic> raw) {
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;
    final verified = data['verified'];
    return XProfile(
      id: '${data['id'] ?? ''}',
      username: '${data['username'] ?? ''}',
      name: _text(data['name']),
      picture: _text(data['profile_image_url']),
      verified: verified is bool ? verified : null,
      email: _text(data['confirmed_email']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'picture': picture,
    'verified': verified,
    'email': email,
  };
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// `/2/users/me` URL asking for the fields the granted [scopes] allow.
String xUserInfoUrl([
  String endpoint = xUserInfoEndpoint,
  List<String> scopes = xDefaultScopes,
]) {
  final fields = [
    ..._baseUserFields,
    if (scopes.contains(xEmailScope)) 'confirmed_email',
  ];
  final separator = endpoint.contains('?') ? '&' : '?';
  return '$endpoint${separator}user.fields=${fields.join(',')}';
}

/// X as seen by the core: a public client with PKCE (S256). X is not
/// OpenID Connect, so there is no id_token and no nonce.
const xProvider = ProviderConfig<XProfile>(
  id: 'x',
  authorizationEndpoint: xAuthorizationEndpoint,
  tokenEndpoint: xTokenEndpoint,
  userInfoEndpoint: xUserInfoEndpoint,
  revocationEndpoint: xRevocationEndpoint,
  defaultScopes: xDefaultScopes,
  mapProfile: XProfile.fromJson,
);

class XLogin extends ProviderLogin<XProfile> {
  XLogin(super.provider, {super.httpClient});

  /// The user fields X returns depend on the scopes of this sign-in.
  @override
  Future<SignInResult<XProfile>> signIn(SignInOptions options) {
    final endpoint = provider.userInfoEndpoint;
    if (endpoint == null) {
      return super.signIn(options);
    }
    return ProviderLogin(
      provider.copyWith(
        userInfoEndpoint: xUserInfoUrl(
          endpoint,
          options.scopes ?? provider.defaultScopes,
        ),
      ),
      httpClient: httpClient,
    ).signIn(options);
  }

  /// Trades a refresh token for a new access token (needs [xOfflineScope] at
  /// sign-in). Store the refresh token that comes back: assume the old one
  /// stops working.
  Future<TokenResponse> refresh({
    required String clientId,
    required String refreshToken,
  }) => refreshAccessToken(
    tokenEndpoint: provider.tokenEndpoint ?? xTokenEndpoint,
    clientId: clientId,
    refreshToken: refreshToken,
    client: httpClient,
  );
}

/// Builds an X login. Point the endpoints at a test server, or add
/// authorization parameters.
XLogin createXLogin({
  String? authorizationEndpoint,
  String? tokenEndpoint,
  String? userInfoEndpoint,
  String? revocationEndpoint,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => XLogin(
  xProvider.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    tokenEndpoint: tokenEndpoint,
    userInfoEndpoint: userInfoEndpoint,
    revocationEndpoint: revocationEndpoint,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

/// Default instance against X.
final xLogin = createXLogin();
