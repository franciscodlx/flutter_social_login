import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_linkedin/social_auth_linkedin.dart';

const options = SignInOptions(
  clientId: '86abc',
  redirectUri: 'https://api.miapp.com/auth/linkedin/callback',
  callbackUri: 'miapp://callback',
);

void main() {
  late FakeBrowser browser;

  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  group('linkedInLogin', () {
    test(
      'requests the OpenID Connect scopes at LinkedIn, without PKCE or nonce',
      () async {
        final result = await linkedInLogin.signIn(options);
        final sent = Uri.parse(browser.calls.single.url);

        expect(
          sent.replace(query: '').toString(),
          'https://www.linkedin.com/oauth/v2/authorization?',
        );
        expect(sent.queryParameters, {
          'response_type': 'code',
          'client_id': '86abc',
          'redirect_uri': options.redirectUri,
          'scope': 'openid profile email',
          'state': result.state,
        });
        expect(browser.calls.single.callbackUrl, 'miapp://callback');
      },
    );

    test('returns what the backend needs and never a token', () async {
      final result = await linkedInLogin.signIn(options);
      expect(result.code, 'the-code');
      expect(result.redirectUri, options.redirectUri);
      expect(result.codeVerifier, isNull);
      expect(result.accessToken, isNull);
    });

    test('refuses to exchange the code on the device', () async {
      await expectLater(
        linkedInLogin.signIn(options.copyWith(exchangeCode: true)),
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

    for (final error in linkedInCancelErrors) {
      test('reports $error as CANCELLED', () async {
        SocialAuthCorePlatform.instance = browser = FakeBrowser.approving({
          'error': error,
          'error_description': 'The user cancelled',
        });
        await expectLater(
          linkedInLogin.signIn(options),
          throwsA(
            isA<AuthException>()
                .having((e) => e.code, 'code', AuthErrorCode.cancelled)
                .having((e) => e.providerError, 'providerError', error),
          ),
        );
      });
    }

    test('accepts extra parameters and a test server', () async {
      final login = createLinkedInLogin(
        authorizationEndpoint: 'http://localhost:4000/authorize',
        extraAuthParams: {'enable_extended_login': 'true'},
      );
      await login.signIn(options.copyWith(scopes: ['openid']));
      final sent = Uri.parse(browser.calls.single.url);
      expect(sent.path, '/authorize');
      expect(sent.host, 'localhost');
      expect(sent.queryParameters['enable_extended_login'], 'true');
      expect(sent.queryParameters['scope'], 'openid');
    });
  });

  group('LinkedInProfile.fromJson', () {
    test('maps the userinfo response', () {
      final profile = LinkedInProfile.fromJson({
        'sub': '782bbtaQ',
        'name': 'John Doe',
        'given_name': 'John',
        'family_name': 'Doe',
        'picture': 'https://media.licdn.com/p.jpg',
        'locale': 'en-US',
        'email': 'doe@email.com',
        'email_verified': true,
      });
      expect(profile.toJson(), {
        'id': '782bbtaQ',
        'name': 'John Doe',
        'givenName': 'John',
        'familyName': 'Doe',
        'picture': 'https://media.licdn.com/p.jpg',
        'locale': 'en-US',
        'email': 'doe@email.com',
        'emailVerified': true,
      });
    });

    test('handles the object locale and a missing email', () {
      final profile = LinkedInProfile.fromJson({
        'sub': 'x',
        'locale': {'language': 'es', 'country': 'MX'},
        'email_verified': 'true',
      });
      expect(profile.locale, 'es-MX');
      expect(profile.email, isNull);
      expect(profile.emailVerified, isTrue);
    });
  });
}
