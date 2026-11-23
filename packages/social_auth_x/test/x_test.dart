import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_x/social_auth_x.dart';

const options = SignInOptions(
  clientId: 'x-client',
  redirectUri: 'miapp://callback',
);

const user = {
  'data': {
    'id': '2244994945',
    'name': 'X Dev',
    'username': 'XDevelopers',
    'profile_image_url': 'https://pbs.twimg.com/a_normal.jpg',
    'verified': true,
  },
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

String s256(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

void main() {
  late FakeBrowser browser;
  final requests = <http.Request>[];

  /// Answers the token, users/me and revoke endpoints like X does.
  MockClient serveX({
    Object userBody = user,
    Map<String, Object?> tokens = const {
      'token_type': 'bearer',
      'expires_in': 7200,
      'access_token': 'at-1',
      'scope': 'users.read tweet.read',
    },
  }) => MockClient((request) async {
    requests.add(request);
    if (request.url.toString() == xTokenEndpoint) {
      return json(tokens);
    }
    if (request.url.toString().startsWith(xUserInfoEndpoint)) {
      return json(userBody);
    }
    return json({'revoked': true});
  });

  Iterable<http.Request> callsTo(String prefix) =>
      requests.where((r) => r.url.toString().startsWith(prefix));

  setUp(() {
    requests.clear();
    SocialAuthCorePlatform.instance = browser = FakeBrowser.approving();
  });

  group('signIn', () {
    test('sends an OAuth 2.0 + PKCE (S256) request to x.com', () async {
      final result = await xLogin.signIn(options);
      final sent = Uri.parse(browser.calls.single.url);

      expect(sent.replace(query: '').toString(), '$xAuthorizationEndpoint?');
      expect(sent.queryParameters, {
        'response_type': 'code',
        'client_id': 'x-client',
        'redirect_uri': 'miapp://callback',
        'scope': 'users.read tweet.read',
        'state': result.state,
        'code_challenge': s256(result.codeVerifier!),
        'code_challenge_method': 'S256',
      });
    });

    test(
      'returns code and verifier for a backend exchange by default',
      () async {
        final login = createXLogin(httpClient: serveX());
        final result = await login.signIn(options);
        expect(result.code, 'the-code');
        expect(result.codeVerifier, isNotEmpty);
        expect(result.accessToken, isNull);
        expect(requests, isEmpty);
      },
    );

    test('exchanges on-device as a public client, no secret', () async {
      final login = createXLogin(httpClient: serveX());
      final result = await login.signIn(options.copyWith(exchangeCode: true));

      final token = callsTo(xTokenEndpoint).single;
      expect(token.bodyFields, {
        'grant_type': 'authorization_code',
        'code': 'the-code',
        'redirect_uri': 'miapp://callback',
        'client_id': 'x-client',
        'code_verifier': result.codeVerifier,
      });
      expect(token.headers['authorization'], isNull);
      expect(result.accessToken, 'at-1');
      expect(result.expiresIn, 7200);
      expect(result.refreshToken, isNull);
      expect(result.profile!.toJson(), {
        'id': '2244994945',
        'username': 'XDevelopers',
        'name': 'X Dev',
        'picture': 'https://pbs.twimg.com/a_normal.jpg',
        'verified': true,
        'email': null,
      });
    });

    test('asks for confirmed_email only with users.email', () async {
      await createXLogin(
        httpClient: serveX(),
      ).signIn(options.copyWith(exchangeCode: true));
      expect(
        callsTo(xUserInfoEndpoint).single.url.toString(),
        '$xUserInfoEndpoint?user.fields=id,name,username,profile_image_url,verified',
      );

      requests.clear();
      final result =
          await createXLogin(
            httpClient: serveX(
              userBody: {
                'data': {
                  ...user['data']!,
                  'confirmed_email': 'dev@example.com',
                },
              },
            ),
          ).signIn(
            options.copyWith(
              exchangeCode: true,
              scopes: ['users.read', 'tweet.read', xEmailScope],
            ),
          );
      expect(
        callsTo(xUserInfoEndpoint).single.url.toString(),
        endsWith(',confirmed_email'),
      );
      expect(result.profile!.email, 'dev@example.com');
    });

    test('returns the refresh token with offline.access', () async {
      final result =
          await createXLogin(
            httpClient: serveX(
              tokens: {'access_token': 'at-1', 'refresh_token': 'rt-1'},
            ),
          ).signIn(
            options.copyWith(
              exchangeCode: true,
              scopes: [...xDefaultScopes, xOfflineScope],
            ),
          );
      expect(
        browser.sentParams['scope'],
        'users.read tweet.read offline.access',
      );
      expect(result.refreshToken, 'rt-1');
    });

    test('reports a rejection as CANCELLED', () async {
      SocialAuthCorePlatform.instance = FakeBrowser.approving({
        'error': 'access_denied',
      });
      await expectLater(
        xLogin.signIn(options),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.cancelled)
              .having((e) => e.providerError, 'error', 'access_denied'),
        ),
      );
    });

    test('surfaces X token errors as PROVIDER_ERROR', () async {
      final login = createXLogin(
        httpClient: MockClient(
          (_) async => json({
            'error': 'invalid_request',
            'error_description':
                'Value passed for the authorization code was invalid.',
          }, 400),
        ),
      );
      await expectLater(
        login.signIn(options.copyWith(exchangeCode: true)),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.providerError)
              .having((e) => e.providerError, 'error', 'invalid_request')
              .having((e) => e.status, 'status', 400),
        ),
      );
    });
  });

  group('refresh and signOut', () {
    test('refreshes as a public client', () async {
      final login = createXLogin(
        httpClient: serveX(
          tokens: {'access_token': 'at-2', 'refresh_token': 'rt-2'},
        ),
      );
      final tokens = await login.refresh(
        clientId: 'x-client',
        refreshToken: 'rt-1',
      );
      expect(requests.single.url.toString(), xTokenEndpoint);
      expect(requests.single.bodyFields, {
        'grant_type': 'refresh_token',
        'refresh_token': 'rt-1',
        'client_id': 'x-client',
      });
      expect(tokens.accessToken, 'at-2');
      expect(tokens.refreshToken, 'rt-2');
    });

    test('revokes the token on signOut', () async {
      await createXLogin(
        httpClient: serveX(),
      ).signOut(clientId: 'x-client', token: 'at-1');
      expect(requests.single.url.toString(), xRevocationEndpoint);
      expect(requests.single.bodyFields, {
        'token': 'at-1',
        'client_id': 'x-client',
      });
    });

    test('uses the endpoints of a custom instance', () async {
      final login = createXLogin(
        authorizationEndpoint: 'http://localhost:4000/authorize',
        tokenEndpoint: 'http://localhost:4000/token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return json({'access_token': 'at-2'});
        }),
      );
      await login.signIn(options);
      expect(
        browser.calls.single.url,
        startsWith('http://localhost:4000/authorize?'),
      );
      await login.refresh(clientId: 'x-client', refreshToken: 'rt-1');
      expect(requests.single.url.toString(), 'http://localhost:4000/token');
    });
  });

  group('XProfile / xUserInfoUrl', () {
    test('accepts the enveloped and the bare user object', () {
      expect(XProfile.fromJson(user).username, 'XDevelopers');
      expect(XProfile.fromJson(user['data']!).id, '2244994945');
    });

    test('keeps an existing query string', () {
      expect(
        xUserInfoUrl('https://h/2/users/me?x=1', ['users.read']),
        'https://h/2/users/me?x=1&user.fields=id,name,username,profile_image_url,verified',
      );
    });
  });
}
