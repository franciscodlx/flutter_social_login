import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_telegram/social_auth_telegram.dart';

const options = SignInOptions(
  clientId: '123456789',
  redirectUri: 'https://api.miapp.com/auth/telegram/callback',
  callbackUri: 'miapp://callback',
);

String s256(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

Matcher throwsAuth(AuthErrorCode code) =>
    throwsA(isA<AuthException>().having((e) => e.code, 'code', code));

void main() {
  late FakeBrowser browser;

  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  String endpoint() =>
      Uri.parse(browser.calls.last.url).replace(query: '').toString();

  group('telegramLogin', () {
    test('sends an OpenID Connect request with PKCE (S256)', () async {
      final result = await telegramLogin.signIn(options);
      expect(endpoint(), '$telegramAuthorizationEndpoint?');
      expect(browser.sentParams, {
        'response_type': 'code',
        'client_id': '123456789',
        'redirect_uri': options.redirectUri,
        'scope': 'openid profile',
        'state': result.state,
        'code_challenge': s256(result.codeVerifier!),
        'code_challenge_method': 'S256',
      });
      expect(browser.calls.single.callbackUrl, 'miapp://callback');
    });

    test('asks for the phone when the scope is added', () async {
      await telegramLogin.signIn(
        options.copyWith(
          scopes: [...telegramDefaultScopes, telegramPhoneScope],
        ),
      );
      expect(browser.sentParams['scope'], 'openid profile phone');
    });

    test('returns code and verifier for the backend, never a token', () async {
      final result = await telegramLogin.signIn(options);
      expect(result.code, 'the-code');
      expect(result.redirectUri, options.redirectUri);
      expect(result.codeVerifier, isNotEmpty);
      expect(result.idToken, isNull);
    });

    test('refuses to exchange the code on the device', () async {
      await expectLater(
        telegramLogin.signIn(options.copyWith(exchangeCode: true)),
        throwsAuth(AuthErrorCode.invalidConfig),
      );
    });

    test('reports a rejection as CANCELLED', () async {
      browser.respond = (url, callback) => '$callback?error=access_denied';
      await expectLater(
        telegramLogin.signIn(options),
        throwsAuth(AuthErrorCode.cancelled),
      );
    });

    test('accepts overrides', () async {
      await createTelegramLogin(
        authorizationEndpoint: 'http://localhost:4000/authorize',
        defaultScopes: ['openid'],
      ).signIn(options);
      expect(endpoint(), 'http://localhost:4000/authorize?');
      expect(browser.sentParams['scope'], 'openid');
    });
  });

  test('TelegramProfile.fromJson maps the id_token claims', () {
    final profile = TelegramProfile.fromJson({
      'sub': '1234567890123',
      'id': 987654321,
      'name': 'Ada Lovelace',
      'preferred_username': 'ada',
      'picture': 'https://cdn.telegram.org/a.jpg',
      'phone_number': '+5215500000000',
    });
    expect(profile.id, '1234567890123');
    expect(profile.telegramId, '987654321');
    expect(profile.name, 'Ada Lovelace');
    expect(profile.username, 'ada');
    expect(profile.picture, 'https://cdn.telegram.org/a.jpg');
    expect(profile.phoneNumber, '+5215500000000');

    final minimal = TelegramProfile.fromJson({'sub': '1'});
    expect(minimal.id, '1');
    expect(minimal.telegramId, isNull);
    expect(minimal.phoneNumber, isNull);
  });
}
