import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

const tikTokAuthorizationEndpoint = 'https://www.tiktok.com/v2/auth/authorize/';

/// For your backend: the token request needs the client secret.
const tikTokTokenEndpoint = 'https://open.tiktokapis.com/v2/oauth/token/';
const tikTokRevocationEndpoint = 'https://open.tiktokapis.com/v2/oauth/revoke/';
const tikTokUserInfoEndpoint = 'https://open.tiktokapis.com/v2/user/info/';

/// Added by default to every app with Login Kit. Other scopes need approval.
const tikTokDefaultScopes = ['user.info.basic'];

/// Fields of `/v2/user/info/` that `user.info.basic` unlocks.
const tikTokBasicFields = ['open_id', 'union_id', 'avatar_url', 'display_name'];

/// Fields that need the `user.info.profile` scope.
const tikTokProfileFields = [
  'username',
  'bio_description',
  'profile_deep_link',
  'is_verified',
];

/// `/v2/user/info/` URL with the required `fields` parameter.
String tikTokUserInfoUrl([
  List<String> fields = tikTokBasicFields,
  String endpoint = tikTokUserInfoEndpoint,
]) =>
    '$endpoint${endpoint.contains('?') ? '&' : '?'}fields=${fields.join(',')}';

class TikTokProfile {
  const TikTokProfile({
    required this.id,
    this.unionId,
    this.displayName,
    this.picture,
    this.username,
    this.verified,
  });

  /// Maps the `/v2/user/info/` response (`{data: {user}}`), or the user
  /// object itself. TikTok has no email field.
  factory TikTokProfile.fromJson(Map<String, dynamic> raw) {
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    String? text(Object? value) =>
        value is String && value.isNotEmpty ? value : null;
    final verified = user['is_verified'];
    return TikTokProfile(
      id: '${user['open_id'] ?? ''}',
      unionId: text(user['union_id']),
      displayName: text(user['display_name']),
      picture: text(user['avatar_url']),
      username: text(user['username']),
      verified: verified is bool ? verified : null,
    );
  }

  /// `open_id`: the user's id for your app.
  final String id;

  /// Same user across the apps of one developer.
  final String? unionId;
  final String? displayName;
  final String? picture;

  /// Needs `user.info.profile`.
  final String? username;
  final bool? verified;
}

/// Scopes the user actually granted, from the `scopes` parameter of the
/// redirect.
List<String> grantedTikTokScopes(SignInResult<Object?> result) =>
    (result.params['scopes'] ?? '')
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList();

const tikTokProvider = ProviderConfig<TikTokProfile>(
  id: 'tiktok',
  authorizationEndpoint: tikTokAuthorizationEndpoint,
  // No tokenEndpoint on purpose: the token request needs the client secret,
  // so the code is exchanged by your backend, never by the app.
  defaultScopes: tikTokDefaultScopes,
  scopeSeparator: ',',
  // TikTok calls the client id "client key".
  clientIdParam: 'client_key',
  // The web flow has no PKCE (TikTok only defines it, hex-encoded, for its
  // desktop and native SDK flows); `state` is generated and verified here.
  usePkce: false,
  mapProfile: TikTokProfile.fromJson,
);

/// Builds a TikTok login. [authorizationEndpoint] points it at a test
/// server; `extraAuthParams: {'disable_auto_auth': '1'}` always shows the
/// authorization page.
ProviderLogin<TikTokProfile> createTikTokLogin({
  String? authorizationEndpoint,
  List<String>? defaultScopes,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => ProviderLogin(
  tikTokProvider.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    defaultScopes: defaultScopes,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

final tikTokLogin = createTikTokLogin();
