import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_tiktok/social_auth_tiktok.dart';

const options = SignInOptions(
  clientId: 'awx1234567890',
  redirectUri: 'https://api.miapp.com/auth/tiktok/callback',
  callbackUri: 'miapp://callback',
);

Matcher throwsAuth(AuthErrorCode code) =>
    throwsA(isA<AuthException>().having((e) => e.code, 'code', code));

void main() {
  late FakeBrowser browser;

  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  String endpoint() =>
      Uri.parse(browser.calls.last.url).replace(query: '').toString();

  group('tikTokLogin', () {
    test('sends client_key, comma scopes and state, without PKCE', () async {
      final result = await tikTokLogin.signIn(
        options.copyWith(scopes: ['user.info.basic', 'user.info.profile']),
      );
      expect(endpoint(), '$tikTokAuthorizationEndpoint?');
      expect(browser.sentParams, {
        'response_type': 'code',
        'client_key': 'awx1234567890',
        'redirect_uri': options.redirectUri,
        'scope': 'user.info.basic,user.info.profile',
        'state': result.state,
      });
      expect(result.codeVerifier, isNull);
      expect(browser.calls.single.callbackUrl, 'miapp://callback');
    });

    test('returns the code and the granted scopes, never a token', () async {
      SocialAuthCorePlatform.instance = FakeBrowser.approving({
        'code': 'the-code',
        'scopes': 'user.info.basic,user.info.profile',
      });
      final result = await tikTokLogin.signIn(options);
      expect(result.code, 'the-code');
      expect(grantedTikTokScopes(result), [
        'user.info.basic',
        'user.info.profile',
      ]);
      expect(result.accessToken, isNull);
    });

    test('refuses to exchange the code on the device', () async {
      await expectLater(
        tikTokLogin.signIn(options.copyWith(exchangeCode: true)),
        throwsAuth(AuthErrorCode.invalidConfig),
      );
    });

    test('reports a rejection as CANCELLED', () async {
      browser.respond = (url, callback) => '$callback?error=access_denied';
      await expectLater(
        tikTokLogin.signIn(options),
        throwsAuth(AuthErrorCode.cancelled),
      );
    });

    test('accepts overrides', () async {
      await createTikTokLogin(
        authorizationEndpoint: 'http://localhost:4000/authorize',
        extraAuthParams: {'disable_auto_auth': '1'},
      ).signIn(options);
      expect(endpoint(), 'http://localhost:4000/authorize?');
      expect(browser.sentParams['disable_auto_auth'], '1');
      expect(browser.sentParams['client_key'], 'awx1234567890');
    });
  });

  group('helpers', () {
    test('TikTokProfile.fromJson maps /v2/user/info/', () {
      final profile = TikTokProfile.fromJson({
        'data': {
          'user': {
            'open_id': '723f24d7-e717-40f8-a2b6-cb8464cd23b4',
            'union_id': 'c9c60f44-a68e-4f5d-84dd-ce22faeb0ba1',
            'avatar_url': 'https://p19-sign.tiktokcdn-us.com/a.jpeg',
            'display_name': 'Ada',
          },
        },
        'error': {'code': 'ok', 'message': '', 'log_id': 'x'},
      });
      expect(profile.id, '723f24d7-e717-40f8-a2b6-cb8464cd23b4');
      expect(profile.unionId, 'c9c60f44-a68e-4f5d-84dd-ce22faeb0ba1');
      expect(profile.displayName, 'Ada');
      expect(profile.picture, 'https://p19-sign.tiktokcdn-us.com/a.jpeg');
      expect(profile.username, isNull);
      expect(profile.verified, isNull);
    });

    test('tikTokUserInfoUrl adds the fields parameter', () {
      expect(
        tikTokUserInfoUrl(),
        'https://open.tiktokapis.com/v2/user/info/'
        '?fields=open_id,union_id,avatar_url,display_name',
      );
      expect(
        tikTokUserInfoUrl(['open_id', 'username']),
        contains('fields=open_id,username'),
      );
    });
  });
}
