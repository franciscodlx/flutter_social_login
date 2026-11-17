import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

/// Country of the accounts that sign in. Each account belongs to one site,
/// so the user must authorize on the host of the country where it was
/// created.
enum MercadoLibreCountry {
  ar('auth.mercadolibre.com.ar'),
  bo('auth.mercadolibre.com.bo'),
  br('auth.mercadolivre.com.br'),
  cl('auth.mercadolibre.cl'),
  co('auth.mercadolibre.com.co'),
  cr('auth.mercadolibre.co.cr'),
  do_('auth.mercadolibre.com.do'),
  ec('auth.mercadolibre.com.ec'),
  mx('auth.mercadolibre.com.mx'),
  pa('auth.mercadolibre.com.pa'),
  pe('auth.mercadolibre.com.pe'),
  py('auth.mercadolibre.com.py'),
  uy('auth.mercadolibre.com.uy'),
  ve('auth.mercadolibre.com.ve');

  const MercadoLibreCountry(this.authHost);

  /// Authorization host of the country's site.
  final String authHost;

  /// ISO 3166 code, e.g. `MX`.
  String get code => name.replaceAll('_', '').toUpperCase();

  String get authorizationEndpoint => 'https://$authHost/authorization';

  /// Looks a country up by its ISO code (`MX`, `br`, …).
  static MercadoLibreCountry fromCode(String code) {
    final upper = code.toUpperCase();
    for (final country in values) {
      if (country.code == upper) {
        return country;
      }
    }
    throw ArgumentError.value(code, 'code', 'Unknown Mercado Libre country');
  }
}

/// For your backend: the token request needs the client secret.
const mercadoLibreTokenEndpoint = 'https://api.mercadolibre.com/oauth/token';
const mercadoLibreUserInfoEndpoint = 'https://api.mercadolibre.com/users/me';

class MercadoLibreProfile {
  const MercadoLibreProfile({
    required this.id,
    this.nickname,
    this.firstName,
    this.lastName,
    this.email,
    this.countryId,
    this.siteId,
    this.picture,
  });

  /// Numeric user id, as a string.
  final String id;
  final String? nickname;
  final String? firstName;
  final String? lastName;
  final String? email;

  /// e.g. `MX`.
  final String? countryId;

  /// e.g. `MLM`.
  final String? siteId;
  final String? picture;

  /// Maps the `GET /users/me` response.
  factory MercadoLibreProfile.fromJson(Map<String, dynamic> raw) {
    final thumbnail = raw['thumbnail'];
    return MercadoLibreProfile(
      id: '${raw['id'] ?? ''}',
      nickname: _text(raw['nickname']),
      firstName: _text(raw['first_name']),
      lastName: _text(raw['last_name']),
      email: _text(raw['email']),
      countryId: _text(raw['country_id']),
      siteId: _text(raw['site_id']),
      picture: thumbnail is Map ? _text(thumbnail['picture_url']) : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'countryId': countryId,
    'siteId': siteId,
    'picture': picture,
  };
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Mercado Libre as seen by the core for [country].
///
/// No token endpoint on purpose: the token request needs the client secret,
/// so the code and the PKCE verifier go to your backend. Scopes (`read`,
/// `write`, `offline_access`) are set in the application's settings, not in
/// the request. PKCE (S256) stays on; enable it in the application too, so
/// the token endpoint enforces the verifier.
ProviderConfig<MercadoLibreProfile> mercadoLibreProvider(
  MercadoLibreCountry country,
) => ProviderConfig<MercadoLibreProfile>(
  id: 'mercadolibre',
  authorizationEndpoint: country.authorizationEndpoint,
  mapProfile: MercadoLibreProfile.fromJson,
);

/// Builds a Mercado Libre login for one [country]. Point
/// [authorizationEndpoint] at a test server if needed.
ProviderLogin<MercadoLibreProfile> createMercadoLibreLogin({
  required MercadoLibreCountry country,
  String? authorizationEndpoint,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => ProviderLogin(
  mercadoLibreProvider(country).copyWith(
    authorizationEndpoint: authorizationEndpoint,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);
