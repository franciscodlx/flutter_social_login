import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_twitch/social_auth_twitch.dart';

const options = SignInOptions(
  clientId: 'hof5gwx0su6owfnys0nyan9c87zr6t',
  redirectUri: 'https://api.miapp.com/auth/twitch/callback',
  callbackUri: 'miapp://callback',
);

void main() {
  late FakeBrowser browser;

  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  group('twitchLogin', () {
    test('sends scopes, state, nonce and claims, without PKCE', () async {
      final result = await twitchLogin.signIn(options);
      final sent = Uri.parse(browser.calls.single.url);

      expect(
        sent.replace(query: '').toString(),
        '$twitchAuthorizationEndpoint?',
      );
      expect(sent.queryParameters, {
        'response_type': 'code',
        'client_id': options.clientId,
        'redirect_uri': options.redirectUri,
        'scope': 'openid user:read:email',
        'state': result.state,
        'nonce': result.nonce,
        'claims': twitchClaims(),
      });
      expect(result.nonce, isNotEmpty);
      expect(browser.calls.single.callbackUrl, 'miapp://callback');
    });

    test('returns code and nonce for the backend, never a token', () async {
      final result = await twitchLogin.signIn(options);
      expect(result.code, 'the-code');
      expect(result.redirectUri, options.redirectUri);
      expect(result.codeVerifier, isNull);
      expect(result.accessToken, isNull);
    });

    test('refuses to exchange the code on the device', () async {
      await expectLater(
        twitchLogin.signIn(options.copyWith(exchangeCode: true)),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidConfig,
          ),
        ),
      );
      expect(browser.calls, isEmpty);
    });

    test('reports a rejection as CANCELLED', () async {
      SocialAuthCorePlatform.instance = FakeBrowser.approving({
        'error': 'access_denied',
        'error_description': 'The user denied you access',
      });
      await expectLater(
        twitchLogin.signIn(options),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.cancelled)
              .having((e) => e.providerError, 'error', 'access_denied'),
        ),
      );
    });

    test('accepts other parameters and a test server', () async {
      await createTwitchLogin(
        authorizationEndpoint: 'http://localhost:4000/authorize',
        extraAuthParams: {
          'claims': twitchClaims([TwitchClaim.picture]),
          'force_verify': 'true',
        },
      ).signIn(options);
      final sent = Uri.parse(browser.calls.single.url);
      expect(sent.host, 'localhost');
      expect(sent.queryParameters['force_verify'], 'true');
      expect(jsonDecode(sent.queryParameters['claims']!), {
        'id_token': {'picture': null},
        'userinfo': {'picture': null},
      });
    });
  });

  test('twitchClaims asks for the same claims in id_token and userinfo', () {
    final claims = jsonDecode(twitchClaims()) as Map<String, dynamic>;
    expect((claims['id_token'] as Map).keys, twitchDefaultClaims);
    expect(claims['userinfo'], claims['id_token']);
  });

  test('TwitchProfile.fromJson maps userinfo', () {
    expect(
      TwitchProfile.fromJson({
        'sub': '713936733',
        'preferred_username': 'ada',
        'picture': 'https://static-cdn.jtvnw.net/a.png',
        'email': 'ada@example.com',
        'email_verified': true,
      }).toJson(),
      {
        'id': '713936733',
        'username': 'ada',
        'picture': 'https://static-cdn.jtvnw.net/a.png',
        'email': 'ada@example.com',
        'emailVerified': true,
      },
    );
    expect(TwitchProfile.fromJson({'sub': 'x'}).email, isNull);
  });
}
