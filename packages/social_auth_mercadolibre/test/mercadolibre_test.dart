import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_mercadolibre/social_auth_mercadolibre.dart';

const options = SignInOptions(
  clientId: '1234567890',
  redirectUri: 'https://api.miapp.com/auth/mercadolibre/callback',
  callbackUri: 'miapp://callback',
);

String s256(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

void main() {
  late FakeBrowser browser;

  setUp(
    () => SocialAuthCorePlatform.instance = browser = FakeBrowser.approving(),
  );

  group('MercadoLibreCountry', () {
    test('uses the authorization host of the country', () {
      expect(
        MercadoLibreCountry.mx.authorizationEndpoint,
        'https://auth.mercadolibre.com.mx/authorization',
      );
      expect(
        MercadoLibreCountry.br.authorizationEndpoint,
        'https://auth.mercadolivre.com.br/authorization',
      );
      expect(
        MercadoLibreCountry.cl.authorizationEndpoint,
        'https://auth.mercadolibre.cl/authorization',
      );
    });

    test('looks countries up by ISO code', () {
      expect(MercadoLibreCountry.fromCode('mx'), MercadoLibreCountry.mx);
      expect(MercadoLibreCountry.fromCode('DO'), MercadoLibreCountry.do_);
      expect(MercadoLibreCountry.do_.code, 'DO');
      expect(() => MercadoLibreCountry.fromCode('XX'), throwsArgumentError);
    });
  });

  group('createMercadoLibreLogin', () {
    test(
      'sends state and PKCE, no scope, and waits on the app callback',
      () async {
        final result = await createMercadoLibreLogin(
          country: MercadoLibreCountry.mx,
        ).signIn(options);
        final sent = Uri.parse(browser.calls.single.url);

        expect(
          sent.replace(query: '').toString(),
          'https://auth.mercadolibre.com.mx/authorization?',
        );
        expect(sent.queryParameters, {
          'response_type': 'code',
          'client_id': '1234567890',
          'redirect_uri': options.redirectUri,
          'state': result.state,
          'code_challenge': s256(result.codeVerifier!),
          'code_challenge_method': 'S256',
        });
        expect(browser.calls.single.callbackUrl, 'miapp://callback');
      },
    );

    test('returns code and verifier for the backend, never a token', () async {
      final result = await createMercadoLibreLogin(
        country: MercadoLibreCountry.ar,
      ).signIn(options);
      expect(result.code, 'the-code');
      expect(result.redirectUri, options.redirectUri);
      expect(result.codeVerifier, isNotEmpty);
      expect(result.accessToken, isNull);
    });

    test('refuses to exchange the code on the device', () async {
      await expectLater(
        createMercadoLibreLogin(country: MercadoLibreCountry.mx)
            .signIn(options.copyWith(exchangeCode: true)),
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
      });
      await expectLater(
        createMercadoLibreLogin(country: MercadoLibreCountry.mx)
            .signIn(options),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.cancelled,
          ),
        ),
      );
    });

    test('accepts a test server', () async {
      await createMercadoLibreLogin(
        country: MercadoLibreCountry.mx,
        authorizationEndpoint: 'http://localhost:4000/authorize',
      ).signIn(options);
      expect(
        browser.calls.single.url,
        startsWith('http://localhost:4000/authorize?'),
      );
    });
  });

  test('MercadoLibreProfile.fromJson maps /users/me', () {
    expect(
      MercadoLibreProfile.fromJson({
        'id': 202593498,
        'nickname': 'TETE2870021',
        'first_name': 'Test',
        'last_name': 'Test',
        'email': 'test_user@testuser.com',
        'country_id': 'MX',
        'site_id': 'MLM',
        'thumbnail': {'picture_id': 'x', 'picture_url': 'https://img/x.jpg'},
      }).toJson(),
      {
        'id': '202593498',
        'nickname': 'TETE2870021',
        'firstName': 'Test',
        'lastName': 'Test',
        'email': 'test_user@testuser.com',
        'countryId': 'MX',
        'siteId': 'MLM',
        'picture': 'https://img/x.jpg',
      },
    );
    expect(MercadoLibreProfile.fromJson({'id': 1}).picture, isNull);
  });
}
