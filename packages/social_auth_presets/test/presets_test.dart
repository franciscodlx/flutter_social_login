import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_presets/social_auth_presets.dart';

const options = SignInOptions(
  clientId: 'client-1',
  redirectUri: 'https://api.miapp.com/auth/x/callback',
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

  group('authorization requests', () {
    test('github: space-separated scopes with PKCE', () async {
      final result = await githubLogin.signIn(options);
      expect(endpoint(), 'https://github.com/login/oauth/authorize?');
      expect(browser.sentParams['scope'], 'read:user user:email');
      expect(browser.sentParams['code_challenge_method'], 'S256');
      expect(browser.sentParams['nonce'], isNull);
      expect(result.codeVerifier, isNotEmpty);
    });

    test('discord: identify + email with PKCE', () async {
      await discordLogin.signIn(options);
      expect(endpoint(), 'https://discord.com/oauth2/authorize?');
      expect(browser.sentParams['scope'], 'identify email');
      expect(browser.sentParams['code_challenge'], isNotEmpty);
    });

    test('slack: OpenID Connect with nonce, without PKCE', () async {
      final result = await slackLogin.signIn(options);
      expect(endpoint(), 'https://slack.com/openid/connect/authorize?');
      expect(browser.sentParams['scope'], 'openid profile email');
      expect(browser.sentParams['nonce'], result.nonce);
      expect(browser.sentParams['code_challenge'], isNull);
      expect(result.codeVerifier, isNull);
    });

    test('strava: mobile endpoint, comma scopes, approval_prompt', () async {
      await stravaLogin.signIn(
        const SignInOptions(
          clientId: 'client-1',
          redirectUri: 'https://api.miapp.com/auth/x/callback',
          scopes: ['read', 'activity:read'],
        ),
      );
      expect(endpoint(), 'https://www.strava.com/oauth/mobile/authorize?');
      expect(browser.sentParams['scope'], 'read,activity:read');
      expect(browser.sentParams['approval_prompt'], 'auto');
      expect(browser.sentParams['code_challenge'], isNull);
    });
  });

  group('shared behaviour', () {
    for (final preset in presets.values) {
      test(
        '${preset.id}: returns the code, never exchanges on-device',
        () async {
          final login = createPresetLogin(preset);
          final result = await login.signIn(options);
          expect(result.code, 'the-code');
          expect(result.accessToken, isNull);
          expect(browser.calls.last.callbackUrl, 'miapp://callback');
          await expectLater(
            login.signIn(options.copyWith(exchangeCode: true)),
            throwsAuth(AuthErrorCode.invalidConfig),
          );
        },
      );
    }

    test('reports a denial as CANCELLED', () async {
      browser.respond = (url, callback) => '$callback?error=access_denied';
      await expectLater(
        stravaLogin.signIn(options),
        throwsAuth(AuthErrorCode.cancelled),
      );
    });

    test(
      'discord: accepts its issuer and rejects another (RFC 9207)',
      () async {
        SocialAuthCorePlatform.instance = FakeBrowser.approving({
          'code': 'the-code',
          'iss': 'https://discord.com',
        });
        expect((await discordLogin.signIn(options)).code, 'the-code');

        SocialAuthCorePlatform.instance = FakeBrowser.approving({
          'code': 'the-code',
          'iss': 'https://evil.test',
        });
        await expectLater(
          discordLogin.signIn(options),
          throwsAuth(AuthErrorCode.providerError),
        );
      },
    );

    test('accepts overrides', () async {
      await createPresetLogin(
        githubPreset,
        authorizationEndpoint: 'http://localhost:4000/authorize',
        defaultScopes: ['read:user'],
      ).signIn(options);
      expect(endpoint(), 'http://localhost:4000/authorize?');
      expect(browser.sentParams['scope'], 'read:user');
    });

    test('a custom preset works like the built-in ones', () async {
      const gitlab = Preset(
        config: ProviderConfig(
          id: 'gitlab',
          authorizationEndpoint: 'https://gitlab.com/oauth/authorize',
          defaultScopes: ['read_user'],
          mapProfile: mapGitHubProfile,
        ),
        backend: PresetBackend(tokenEndpoint: 'https://gitlab.com/oauth/token'),
      );
      await createPresetLogin(gitlab).signIn(options);
      expect(endpoint(), 'https://gitlab.com/oauth/authorize?');
      expect(browser.sentParams['code_challenge_method'], 'S256');
    });
  });

  group('profile mappers', () {
    test('github', () {
      final profile = mapGitHubProfile({
        'id': 1,
        'login': 'octocat',
        'name': 'The Octocat',
        'email': null,
        'avatar_url': 'https://avatars.githubusercontent.com/u/1',
      });
      expect(profile.id, '1');
      expect(profile.username, 'octocat');
      expect(profile.name, 'The Octocat');
      expect(profile.email, isNull);
      expect(profile.picture, 'https://avatars.githubusercontent.com/u/1');
    });

    test('discord builds the avatar URL', () {
      final profile = mapDiscordProfile({
        'id': '80351110224678912',
        'username': 'nelly',
        'global_name': 'Nelly',
        'avatar': '8342729096ea3675442027381ff50dfe',
        'email': 'nelly@discord.com',
        'verified': true,
      });
      expect(profile.name, 'Nelly');
      expect(profile.emailVerified, isTrue);
      expect(
        profile.picture,
        'https://cdn.discordapp.com/avatars/80351110224678912/'
        '8342729096ea3675442027381ff50dfe.png',
      );
      expect(mapDiscordProfile({'id': '1', 'avatar': null}).picture, isNull);
    });

    test('slack', () {
      final profile = mapSlackProfile({
        'sub': 'U123',
        'name': 'Ada',
        'email': 'ada@example.com',
        'email_verified': true,
      });
      expect(profile.id, 'U123');
      expect(profile.name, 'Ada');
      expect(profile.emailVerified, isTrue);
    });

    test('strava', () {
      final profile = mapStravaProfile({
        'id': 227615,
        'username': 'ada',
        'firstname': 'Ada',
        'lastname': 'Lovelace',
        'profile': 'https://dgalywyr863hv.cloudfront.net/large.jpg',
      });
      expect(profile.id, '227615');
      expect(profile.name, 'Ada Lovelace');
      expect(profile.picture, 'https://dgalywyr863hv.cloudfront.net/large.jpg');
    });
  });
}
