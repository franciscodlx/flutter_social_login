import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/social_auth_core.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'fakes.dart';

const request = AuthorizeRequest(
  authorizationEndpoint: 'https://idp.test/authorize',
  clientId: 'client-1',
  redirectUri: 'myapp://callback',
  scopes: ['openid', 'email'],
);

Matcher throwsAuth(AuthErrorCode code, [String? providerError]) => throwsA(
  isA<AuthException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.providerError, 'providerError', providerError),
);

void main() {
  late FakeBrowser browser;
  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  test(
    'sends code + PKCE + state and returns the code with the verifier',
    () async {
      final result = await authorize(request);
      final sent = browser.sentParams;

      expect(
        browser.calls.single.url,
        startsWith('https://idp.test/authorize?'),
      );
      expect(sent, {
        'response_type': 'code',
        'client_id': 'client-1',
        'redirect_uri': 'myapp://callback',
        'scope': 'openid email',
        'state': result.state,
        'code_challenge': sha256Base64Url(result.codeVerifier!),
        'code_challenge_method': 'S256',
      });
      expect(result.code, 'the-code');
      expect(result.nonce, isNull);
      expect(result.redirectUri, 'myapp://callback');
      expect(browser.calls.single.callbackUrl, 'myapp://callback');
      expect(browser.calls.single.ephemeral, isFalse);
    },
  );

  test('every sign-in uses a new state and verifier', () async {
    final a = await authorize(request);
    final b = await authorize(request);
    expect(a.state, isNot(b.state));
    expect(a.codeVerifier, isNot(b.codeVerifier));
  });

  test(
    'options: nonce, no PKCE, custom separator and client id name, extras',
    () async {
      final result = await authorize(
        const AuthorizeRequest(
          authorizationEndpoint: 'https://idp.test/authorize',
          clientId: 'key-1',
          redirectUri: 'myapp://callback',
          scopes: ['a', 'b'],
          scopeSeparator: ',',
          usePkce: false,
          useNonce: true,
          clientIdParam: 'client_key',
          extraParams: {'prompt': 'login', 'state': 'attacker'},
          prefersEphemeralSession: true,
        ),
      );
      final sent = browser.sentParams;
      expect(sent['client_key'], 'key-1');
      expect(sent.containsKey('client_id'), isFalse);
      expect(sent['scope'], 'a,b');
      expect(sent['nonce'], result.nonce);
      expect(sent.containsKey('code_challenge'), isFalse);
      expect(sent['prompt'], 'login');
      // Extra params cannot replace the security parameters.
      expect(sent['state'], result.state);
      expect(result.codeVerifier, isNull);
      expect(browser.calls.single.ephemeral, isTrue);
    },
  );

  test(
    'callbackUri: waits on the app URL, reports the provider redirectUri',
    () async {
      final result = await authorize(
        const AuthorizeRequest(
          authorizationEndpoint: 'https://idp.test/authorize',
          clientId: 'client-1',
          redirectUri: 'https://api.test/auth/callback',
          callbackUri: 'myapp://callback',
        ),
      );
      expect(
        browser.sentParams['redirect_uri'],
        'https://api.test/auth/callback',
      );
      expect(browser.calls.single.callbackUrl, 'myapp://callback');
      expect(result.redirectUri, 'https://api.test/auth/callback');
    },
  );

  test(
    'a provider error is reported; access_denied and cancelErrors mean CANCELLED',
    () async {
      SocialAuthCorePlatform.instance = FakeBrowser.approving({
        'error': 'access_denied',
        'error_description': 'The user denied the request',
      });
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.cancelled, 'access_denied'),
      );

      SocialAuthCorePlatform.instance = FakeBrowser.approving({
        'error': 'user_cancelled_login',
      });
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.providerError, 'user_cancelled_login'),
      );
      await expectLater(
        authorize(
          const AuthorizeRequest(
            authorizationEndpoint: 'https://idp.test/authorize',
            clientId: 'client-1',
            redirectUri: 'myapp://callback',
            cancelErrors: ['user_cancelled_login'],
          ),
        ),
        throwsAuth(AuthErrorCode.cancelled, 'user_cancelled_login'),
      );
    },
  );

  test(
    'rejects a wrong state, a missing code and a foreign redirect',
    () async {
      SocialAuthCorePlatform.instance = FakeBrowser()
        ..respond = (url, callback) => '$callback?code=1&state=forged';
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.providerError),
      );

      SocialAuthCorePlatform.instance = FakeBrowser.approving({});
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.providerError),
      );

      SocialAuthCorePlatform.instance = FakeBrowser()
        ..respond = (url, callback) => 'other://callback?code=1';
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.providerError),
      );
    },
  );

  test(
    'a closed browser is CANCELLED and a new sign-in can start afterwards',
    () async {
      SocialAuthCorePlatform.instance = FakeBrowser()
        ..failure = PlatformException(
          code: 'CANCELLED',
          message: 'The user closed the browser',
        );
      await expectLater(
        authorize(request),
        throwsAuth(AuthErrorCode.cancelled),
      );
      SocialAuthCorePlatform.instance = FakeBrowser.approving();
      expect((await authorize(request)).code, 'the-code');
    },
  );

  test('validates the configuration before opening the browser', () async {
    Future<void> invalid(AuthorizeRequest bad) async {
      await expectLater(
        authorize(bad),
        throwsAuth(AuthErrorCode.invalidConfig),
      );
    }

    await invalid(
      const AuthorizeRequest(
        authorizationEndpoint: '',
        clientId: '',
        redirectUri: '',
      ),
    );
    await invalid(
      const AuthorizeRequest(
        authorizationEndpoint: 'http://idp.test/a',
        clientId: 'c',
        redirectUri: 'myapp://cb',
      ),
    );
    await invalid(
      const AuthorizeRequest(
        authorizationEndpoint: 'https://idp.test/a',
        clientId: 'c',
        redirectUri: 'callback',
      ),
    );
    await invalid(
      const AuthorizeRequest(
        authorizationEndpoint: 'https://idp.test/a',
        clientId: 'c',
        redirectUri: 'https://x/cb',
        callbackUri: 'nope',
      ),
    );
    expect(browser.calls, isEmpty);
  });

  test('cancelAuthorize dismisses the browser', () async {
    await cancelAuthorize();
    expect(browser.cancelled, isTrue);
  });
}
