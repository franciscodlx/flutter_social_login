import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_auth_core/social_auth_core.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'fakes.dart';

typedef Profile = ({String id, String email});

final config = ProviderConfig<Profile>(
  id: 'mock',
  authorizationEndpoint: 'https://idp.test/authorize',
  tokenEndpoint: 'https://idp.test/token',
  userInfoEndpoint: 'https://idp.test/userinfo',
  revocationEndpoint: 'https://idp.test/revoke',
  issuer: 'https://idp.test',
  defaultScopes: const ['openid', 'email'],
  useNonce: true,
  mapProfile: (raw) => (id: '${raw['sub']}', email: '${raw['email']}'),
);

const options = SignInOptions(
  clientId: 'client-1',
  redirectUri: 'myapp://callback',
);

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late FakeBrowser browser;
  final requests = <http.Request>[];

  /// Token and userinfo endpoints of a provider that issues an id_token with
  /// the nonce it was sent.
  MockClient idp({Map<String, Object?> tokenExtra = const {}, String? nonce}) =>
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/token') {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          return json({
            'access_token': 'at-1',
            'token_type': 'Bearer',
            'expires_in': '3600',
            'refresh_token': 'rt-1',
            'id_token': makeJwt({
              'iss': 'https://idp.test',
              'aud': 'client-1',
              'sub': 'user-123',
              'exp': now + 3600,
              'nonce': nonce ?? browser.sentParams['nonce'],
            }),
            ...tokenExtra,
          });
        }
        if (request.url.path == '/userinfo') {
          return json({'sub': 'user-123', 'email': 'ada@example.com'});
        }
        return json({});
      });

  setUp(() {
    requests.clear();
    SocialAuthCorePlatform.instance = browser = FakeBrowser.approving();
  });

  test('returns only the code by default, for a backend exchange', () async {
    final result = await ProviderLogin(
      config,
      httpClient: idp(),
    ).signIn(options);
    expect(result.code, 'the-code');
    expect(result.codeVerifier, isNotNull);
    expect(result.nonce, isNotNull);
    expect(result.accessToken, isNull);
    expect(result.profile, isNull);
    expect(requests, isEmpty);
  });

  test('exchanges on-device as a public client, validates the id_token and maps the profile', () async {
    final result = await ProviderLogin(
      config,
      httpClient: idp(),
    ).signIn(options.copyWith(exchangeCode: true));

    final token = requests.first;
    expect(token.method, 'POST');
    expect(
      token.headers['content-type'],
      startsWith('application/x-www-form-urlencoded'),
    );
    expect(token.bodyFields, {
      'grant_type': 'authorization_code',
      'code': 'the-code',
      'redirect_uri': 'myapp://callback',
      'client_id': 'client-1',
      'code_verifier': result.codeVerifier,
    });
    expect(token.bodyFields.containsKey('client_secret'), isFalse);
    expect(requests.last.headers['authorization'], 'Bearer at-1');

    expect(result.accessToken, 'at-1');
    expect(result.refreshToken, 'rt-1');
    expect(result.expiresIn, 3600);
    expect(result.idTokenClaims?['sub'], 'user-123');
    expect(result.profile, (id: 'user-123', email: 'ada@example.com'));
  });

  test('an id_token for another sign-in (nonce) is rejected', () async {
    await expectLater(
      ProviderLogin(
        config,
        httpClient: idp(nonce: 'someone-else'),
      ).signIn(options.copyWith(exchangeCode: true)),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('nonce'),
        ),
      ),
    );
  });

  test(
    'without a userinfo endpoint the profile comes from the id_token',
    () async {
      final login = ProviderLogin(
        ProviderConfig<Profile>(
          id: 'mock',
          authorizationEndpoint: config.authorizationEndpoint,
          tokenEndpoint: config.tokenEndpoint,
          issuer: config.issuer,
          useNonce: true,
          mapProfile: config.mapProfile,
        ),
        httpClient: idp(),
      );
      final result = await login.signIn(options.copyWith(exchangeCode: true));
      expect(result.profile?.id, 'user-123');
      expect(requests, hasLength(1));
    },
  );

  test('provider and transport failures are normalized', () async {
    final denied = MockClient(
      (_) async => json({
        'error': 'invalid_grant',
        'error_description': 'Code expired',
      }, 400),
    );
    await expectLater(
      ProviderLogin(
        config,
        httpClient: denied,
      ).signIn(options.copyWith(exchangeCode: true)),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'code', AuthErrorCode.providerError)
            .having((e) => e.providerError, 'providerError', 'invalid_grant')
            .having((e) => e.message, 'message', 'Code expired')
            .having((e) => e.status, 'status', 400),
      ),
    );

    // REST APIs such as X's answer with problem details instead.
    final notEnrolled = MockClient(
      (_) async => json({
        'title': 'Client Forbidden',
        'detail':
            'This request must be made using an approved developer account.',
        'reason': 'client-not-enrolled',
      }, 403),
    );
    await expectLater(
      fetchUserInfo('https://api.test/2/users/me', 'at', client: notEnrolled),
      throwsA(
        isA<AuthException>()
            .having(
              (e) => e.providerError,
              'providerError',
              'client-not-enrolled',
            )
            .having(
              (e) => e.message,
              'message',
              'This request must be made using an approved developer account.',
            )
            .having((e) => e.status, 'status', 403),
      ),
    );

    final offline = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await expectLater(
      ProviderLogin(
        config,
        httpClient: offline,
      ).signIn(options.copyWith(exchangeCode: true)),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.network,
        ),
      ),
    );
  });

  test(
    'a provider without token endpoint refuses the on-device exchange',
    () async {
      final backendOnly = ProviderLogin(
        ProviderConfig<Profile>(
          id: 'secret',
          authorizationEndpoint: config.authorizationEndpoint,
          mapProfile: config.mapProfile,
        ),
      );
      await expectLater(
        backendOnly.signIn(options.copyWith(exchangeCode: true)),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidConfig,
          ),
        ),
      );
      expect(browser.calls, isEmpty);
    },
  );

  test('signOut revokes the token; refresh works as a public client', () async {
    // No browser session in this test, so the fake needs a fixed nonce.
    final client = idp(nonce: 'unused');
    await ProviderLogin(config, httpClient: client).signOut(
      clientId: 'client-1',
      token: 'at-1',
      tokenTypeHint: 'access_token',
    );
    expect(requests.single.url.path, '/revoke');
    expect(requests.single.bodyFields, {
      'token': 'at-1',
      'token_type_hint': 'access_token',
      'client_id': 'client-1',
    });

    requests.clear();
    await ProviderLogin(
      config,
      httpClient: client,
    ).signOut(clientId: 'client-1');
    expect(requests, isEmpty);

    final tokens = await refreshAccessToken(
      tokenEndpoint: 'https://idp.test/token',
      clientId: 'client-1',
      refreshToken: 'rt-1',
      scopes: const ['openid'],
      client: client,
    );
    expect(requests.single.bodyFields, {
      'grant_type': 'refresh_token',
      'refresh_token': 'rt-1',
      'client_id': 'client-1',
      'scope': 'openid',
    });
    expect(tokens.accessToken, 'at-1');
  });

  test('ProviderLoginController tracks loading, result and error', () async {
    final controller = ProviderLoginController(
      ProviderLogin(config, httpClient: idp()),
      options,
    );
    final states = <bool>[];
    controller.addListener(() => states.add(controller.loading));

    final result = await controller.signIn();
    expect(result?.code, 'the-code');
    expect(controller.result, same(result));
    expect(controller.error, isNull);
    expect(states.first, isTrue);
    expect(controller.loading, isFalse);

    SocialAuthCorePlatform.instance = FakeBrowser.approving({
      'error': 'access_denied',
    });
    expect(await controller.signIn(), isNull);
    expect(controller.result, isNull);
    expect(controller.error?.isCancelled, isTrue);

    await controller.signOut();
    expect(controller.error, isNull);
    controller.dispose();
  });
}
