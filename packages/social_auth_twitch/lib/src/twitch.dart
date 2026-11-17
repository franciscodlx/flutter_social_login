import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

const twitchIssuer = 'https://id.twitch.tv/oauth2';
const twitchAuthorizationEndpoint = 'https://id.twitch.tv/oauth2/authorize';

/// For your backend: Twitch requires the client secret here.
const twitchTokenEndpoint = 'https://id.twitch.tv/oauth2/token';
const twitchUserInfoEndpoint = 'https://id.twitch.tv/oauth2/userinfo';
const twitchJwksUri = 'https://id.twitch.tv/oauth2/keys';

/// For your backend: Twitch asks apps to validate tokens at start and hourly.
const twitchValidateEndpoint = 'https://id.twitch.tv/oauth2/validate';
const twitchRevocationEndpoint = 'https://id.twitch.tv/oauth2/revoke';

/// `openid` for the id_token, `user:read:email` for the email claims.
const twitchDefaultScopes = ['openid', 'user:read:email'];

/// Claims Twitch returns only when asked through the `claims` parameter.
abstract final class TwitchClaim {
  static const email = 'email';
  static const emailVerified = 'email_verified';
  static const picture = 'picture';
  static const preferredUsername = 'preferred_username';
  static const updatedAt = 'updated_at';
}

const twitchDefaultClaims = [
  TwitchClaim.email,
  TwitchClaim.emailVerified,
  TwitchClaim.picture,
  TwitchClaim.preferredUsername,
];

/// Value of the `claims` authorization parameter: Twitch only returns `sub`
/// unless the other claims are requested explicitly. The email claims also
/// need the `user:read:email` scope.
String twitchClaims([List<String> claims = twitchDefaultClaims]) {
  final requested = {for (final claim in claims) claim: null};
  return jsonEncode({'id_token': requested, 'userinfo': requested});
}

class TwitchProfile {
  const TwitchProfile({
    required this.id,
    this.username,
    this.picture,
    this.email,
    this.emailVerified,
  });

  /// `sub`: the Twitch user id.
  final String id;

  /// Display name (`preferred_username`).
  final String? username;
  final String? picture;

  /// Twitch returns no email when it is not verified.
  final String? email;
  final bool? emailVerified;

  /// Maps Twitch's userinfo response (or id_token claims).
  factory TwitchProfile.fromJson(Map<String, dynamic> raw) {
    final verified = raw['email_verified'];
    return TwitchProfile(
      id: '${raw['sub'] ?? ''}',
      username: _text(raw['preferred_username']),
      picture: _text(raw['picture']),
      email: _text(raw['email']),
      emailVerified: verified is bool ? verified : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'picture': picture,
    'email': email,
    'emailVerified': emailVerified,
  };
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Twitch as seen by the core. There is no token endpoint on purpose:
/// Twitch's authorization code grant needs the client secret, so the code is
/// exchanged by your backend, never by the app.
final twitchProvider = ProviderConfig<TwitchProfile>(
  id: 'twitch',
  authorizationEndpoint: twitchAuthorizationEndpoint,
  issuer: twitchIssuer,
  defaultScopes: twitchDefaultScopes,
  // Twitch does not document PKCE; `state` and the OpenID Connect `nonce`
  // are generated here and the backend checks the nonce inside the id_token.
  usePkce: false,
  useNonce: true,
  extraAuthParams: {'claims': twitchClaims()},
  mapProfile: TwitchProfile.fromJson,
);

/// Builds a Twitch login. Point [authorizationEndpoint] at a test server, or
/// replace the authorization parameters, e.g.
/// `{'claims': twitchClaims([TwitchClaim.picture]), 'force_verify': 'true'}`.
ProviderLogin<TwitchProfile> createTwitchLogin({
  String? authorizationEndpoint,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => ProviderLogin(
  twitchProvider.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

/// Default instance against Twitch.
final twitchLogin = createTwitchLogin();
