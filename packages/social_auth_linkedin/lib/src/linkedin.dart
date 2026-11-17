import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

const linkedInIssuer = 'https://www.linkedin.com/oauth';
const linkedInAuthorizationEndpoint =
    'https://www.linkedin.com/oauth/v2/authorization';

/// For your backend: LinkedIn requires the client secret here.
const linkedInTokenEndpoint = 'https://www.linkedin.com/oauth/v2/accessToken';
const linkedInUserInfoEndpoint = 'https://api.linkedin.com/v2/userinfo';
const linkedInJwksUri = 'https://www.linkedin.com/oauth/openid/jwks';

/// Scopes of "Sign In with LinkedIn using OpenID Connect".
const linkedInDefaultScopes = ['openid', 'profile', 'email'];

/// Errors LinkedIn returns when the member backs out.
const linkedInCancelErrors = [
  'user_cancelled_login',
  'user_cancelled_authorize',
];

class LinkedInProfile {
  const LinkedInProfile({
    required this.id,
    this.name,
    this.givenName,
    this.familyName,
    this.picture,
    this.locale,
    this.email,
    this.emailVerified,
  });

  /// `sub`: stable, app-specific member id.
  final String id;
  final String? name;
  final String? givenName;
  final String? familyName;
  final String? picture;

  /// BCP 47 tag, e.g. `es-MX`.
  final String? locale;

  /// Not present in every response.
  final String? email;
  final bool? emailVerified;

  /// Maps LinkedIn's userinfo response (or id_token claims).
  factory LinkedInProfile.fromJson(Map<String, dynamic> raw) {
    final verified = raw['email_verified'];
    return LinkedInProfile(
      id: '${raw['sub'] ?? ''}',
      name: _text(raw['name']),
      givenName: _text(raw['given_name']),
      familyName: _text(raw['family_name']),
      picture: _text(raw['picture']),
      locale: _locale(raw['locale']),
      email: _text(raw['email']),
      emailVerified: verified is bool
          ? verified
          : verified == 'true'
          ? true
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'givenName': givenName,
    'familyName': familyName,
    'picture': picture,
    'locale': locale,
    'email': email,
    'emailVerified': emailVerified,
  };
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String? _locale(Object? value) {
  if (value is String) {
    return _text(value);
  }
  // LinkedIn has also returned {"language": "es", "country": "MX"}.
  if (value is Map) {
    final parts = [
      _text(value['language']),
      _text(value['country']),
    ].whereType<String>();
    return parts.isEmpty ? null : parts.join('-');
  }
  return null;
}

/// LinkedIn as seen by the core. There is no token endpoint on purpose:
/// LinkedIn's token request needs the client secret, so the code is
/// exchanged by your backend, never by the app.
const linkedInProvider = ProviderConfig<LinkedInProfile>(
  id: 'linkedin',
  authorizationEndpoint: linkedInAuthorizationEndpoint,
  issuer: linkedInIssuer,
  defaultScopes: linkedInDefaultScopes,
  // LinkedIn documents neither PKCE nor `nonce` for this flow; `state` is
  // still generated and verified by the core.
  usePkce: false,
  cancelErrors: linkedInCancelErrors,
  mapProfile: LinkedInProfile.fromJson,
);

/// Builds a LinkedIn login. Point [authorizationEndpoint] at a test server,
/// or add authorization parameters such as
/// `{'enable_extended_login': 'true'}`.
ProviderLogin<LinkedInProfile> createLinkedInLogin({
  String? authorizationEndpoint,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => ProviderLogin(
  linkedInProvider.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

/// Default instance against LinkedIn.
final linkedInLogin = createLinkedInLogin();
