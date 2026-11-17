import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

const telegramIssuer = 'https://oauth.telegram.org';
const telegramAuthorizationEndpoint = 'https://oauth.telegram.org/auth';

/// For your backend: the token request needs the client secret from
/// BotFather.
const telegramTokenEndpoint = 'https://oauth.telegram.org/token';
const telegramJwksUri = 'https://oauth.telegram.org/.well-known/jwks.json';

/// `openid` is required; `profile` adds name, username and picture.
const telegramDefaultScopes = ['openid', 'profile'];

/// Adds `phone_number`; the user is asked for consent.
const telegramPhoneScope = 'phone';

/// Lets your bot message the user after login.
const telegramBotAccessScope = 'telegram:bot_access';

class TelegramProfile {
  const TelegramProfile({
    required this.id,
    this.telegramId,
    this.name,
    this.username,
    this.picture,
    this.phoneNumber,
  });

  /// Maps the claims of Telegram's id_token. Telegram has no userinfo
  /// endpoint: the id_token is the only source.
  factory TelegramProfile.fromJson(Map<String, dynamic> raw) {
    String? text(Object? value) =>
        value is String && value.isNotEmpty ? value : null;
    final telegramId = raw['id'];
    return TelegramProfile(
      id: '${raw['sub'] ?? ''}',
      telegramId: telegramId is String || telegramId is num
          ? '$telegramId'
          : null,
      name: text(raw['name']),
      username: text(raw['preferred_username']),
      picture: text(raw['picture']),
      phoneNumber: text(raw['phone_number']),
    );
  }

  /// `sub` of the id_token.
  final String id;

  /// Numeric Telegram user id (`id` claim), when `profile` was granted.
  final String? telegramId;
  final String? name;

  /// `preferred_username`, without the `@`.
  final String? username;
  final String? picture;

  /// Only with the `phone` scope.
  final String? phoneNumber;
}

const telegramProvider = ProviderConfig<TelegramProfile>(
  id: 'telegram',
  authorizationEndpoint: telegramAuthorizationEndpoint,
  // No tokenEndpoint on purpose: the token request is authenticated with the
  // client secret, so the code and the PKCE verifier go to your backend.
  issuer: telegramIssuer,
  defaultScopes: telegramDefaultScopes,
  // PKCE (S256) stays on, as Telegram recommends.
  mapProfile: TelegramProfile.fromJson,
);

/// Builds a Telegram login. [authorizationEndpoint] points it at a test
/// server; [defaultScopes] replaces `openid profile`.
ProviderLogin<TelegramProfile> createTelegramLogin({
  String? authorizationEndpoint,
  List<String>? defaultScopes,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => ProviderLogin(
  telegramProvider.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    defaultScopes: defaultScopes,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

final telegramLogin = createTelegramLogin();
