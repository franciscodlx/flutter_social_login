import 'package:social_auth_core/social_auth_core.dart';

/// Profile shape shared by every preset. [raw] keeps the provider's object.
class PresetProfile {
  const PresetProfile({
    required this.id,
    this.username,
    this.name,
    this.email,
    this.emailVerified,
    this.picture,
    this.raw = const {},
  });

  final String id;
  final String? username;
  final String? name;
  final String? email;
  final bool? emailVerified;
  final String? picture;
  final Map<String, dynamic> raw;

  @override
  String toString() =>
      'PresetProfile(id: $id, username: $username, name: $name, '
      'email: $email, emailVerified: $emailVerified)';
}

/// Endpoints your backend needs. The app does not use them: all four
/// providers require the client secret to exchange the code.
class PresetBackend {
  const PresetBackend({
    required this.tokenEndpoint,
    this.userInfoEndpoint,
    this.revocationEndpoint,
    this.jwksUri,
  });

  final String tokenEndpoint;
  final String? userInfoEndpoint;
  final String? revocationEndpoint;
  final String? jwksUri;
}

/// A provider ready to use: the core config plus what your backend needs.
class Preset {
  const Preset({
    required this.config,
    required this.backend,
    this.redirectIssuer,
  });

  final ProviderConfig<PresetProfile> config;
  final PresetBackend backend;

  /// Expected `iss` parameter of the redirect (RFC 9207), when the provider
  /// sends it.
  final String? redirectIssuer;

  String get id => config.id;
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
bool? _bool(Object? value) => value is bool ? value : null;
String _id(Object? value) => value is String || value is num ? '$value' : '';

/// `GET https://api.github.com/user`. `email` is null when it is private.
PresetProfile mapGitHubProfile(Map<String, dynamic> raw) => PresetProfile(
  id: _id(raw['id']),
  username: _text(raw['login']),
  name: _text(raw['name']),
  email: _text(raw['email']),
  picture: _text(raw['avatar_url']),
  raw: raw,
);

/// `GET https://discord.com/api/users/@me`.
PresetProfile mapDiscordProfile(Map<String, dynamic> raw) {
  final userId = _id(raw['id']);
  final avatar = _text(raw['avatar']);
  return PresetProfile(
    id: userId,
    username: _text(raw['username']),
    name: _text(raw['global_name']),
    email: _text(raw['email']),
    emailVerified: _bool(raw['verified']),
    picture: avatar == null
        ? null
        : 'https://cdn.discordapp.com/avatars/$userId/$avatar.png',
    raw: raw,
  );
}

/// Slack's `openid.connect.userInfo` response or id_token claims.
PresetProfile mapSlackProfile(Map<String, dynamic> raw) => PresetProfile(
  id: _id(raw['sub']),
  name: _text(raw['name']),
  email: _text(raw['email']),
  emailVerified: _bool(raw['email_verified']),
  picture: _text(raw['picture']),
  raw: raw,
);

/// The `athlete` object of Strava's token response.
PresetProfile mapStravaProfile(Map<String, dynamic> raw) {
  final name = [
    _text(raw['firstname']),
    _text(raw['lastname']),
  ].whereType<String>().join(' ');
  return PresetProfile(
    id: _id(raw['id']),
    username: _text(raw['username']),
    name: name.isEmpty ? null : name,
    picture: _text(raw['profile']),
    raw: raw,
  );
}

const githubPreset = Preset(
  config: ProviderConfig(
    id: 'github',
    authorizationEndpoint: 'https://github.com/login/oauth/authorize',
    defaultScopes: ['read:user', 'user:email'],
    // PKCE (S256) on: GitHub supports it, and still requires the secret.
    mapProfile: mapGitHubProfile,
  ),
  backend: PresetBackend(
    tokenEndpoint: 'https://github.com/login/oauth/access_token',
    userInfoEndpoint: 'https://api.github.com/user',
  ),
);

const discordPreset = Preset(
  config: ProviderConfig(
    id: 'discord',
    authorizationEndpoint: 'https://discord.com/oauth2/authorize',
    defaultScopes: ['identify', 'email'],
    // PKCE on, as Discord recommends for production apps.
    mapProfile: mapDiscordProfile,
  ),
  redirectIssuer: 'https://discord.com',
  backend: PresetBackend(
    tokenEndpoint: 'https://discord.com/api/oauth2/token',
    userInfoEndpoint: 'https://discord.com/api/users/@me',
    revocationEndpoint: 'https://discord.com/api/oauth2/token/revoke',
  ),
);

/// Sign in with Slack (OpenID Connect).
const slackPreset = Preset(
  config: ProviderConfig(
    id: 'slack',
    authorizationEndpoint: 'https://slack.com/openid/connect/authorize',
    issuer: 'https://slack.com',
    defaultScopes: ['openid', 'profile', 'email'],
    // Slack documents `nonce` for this flow but not `code_challenge`.
    usePkce: false,
    useNonce: true,
    mapProfile: mapSlackProfile,
  ),
  backend: PresetBackend(
    tokenEndpoint: 'https://slack.com/api/openid.connect.token',
    userInfoEndpoint: 'https://slack.com/api/openid.connect.userInfo',
    jwksUri: 'https://slack.com/openid/connect/keys',
  ),
);

const stravaPreset = Preset(
  config: ProviderConfig(
    id: 'strava',
    // The mobile endpoint falls back to the web page when the Strava app is
    // not installed.
    authorizationEndpoint: 'https://www.strava.com/oauth/mobile/authorize',
    defaultScopes: ['read'],
    scopeSeparator: ',',
    // Strava does not document PKCE.
    usePkce: false,
    extraAuthParams: {'approval_prompt': 'auto'},
    mapProfile: mapStravaProfile,
  ),
  backend: PresetBackend(
    tokenEndpoint: 'https://www.strava.com/oauth/token',
    revocationEndpoint: 'https://www.strava.com/oauth/revoke',
  ),
);

/// Every preset by id.
const presets = <String, Preset>{
  'github': githubPreset,
  'discord': discordPreset,
  'slack': slackPreset,
  'strava': stravaPreset,
};
