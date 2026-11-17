import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core/social_auth_core.dart';

void main() {
  group('url helpers', () {
    test('appendParams encodes, skips nulls and keeps an existing query', () {
      expect(
        appendParams('https://idp.test/authorize', {
          'scope': 'openid profile',
          'nonce': null,
          'redirect_uri': 'myapp://cb?x=1',
        }),
        'https://idp.test/authorize?scope=openid%20profile&redirect_uri=myapp%3A%2F%2Fcb%3Fx%3D1',
      );
      expect(
        appendParams('https://idp.test/a?tenant=1', {'a': 'b'}),
        'https://idp.test/a?tenant=1&a=b',
      );
      expect(appendParams('https://idp.test/a', {}), 'https://idp.test/a');
    });

    test('parseRedirectParams reads query and fragment, query wins', () {
      expect(
        parseRedirectParams('myapp://callback?code=1&state=s#state=x&extra=2'),
        {'code': '1', 'state': 's', 'extra': '2'},
      );
      expect(parseRedirectParams('myapp://callback'), isEmpty);
    });

    test(
      'matchesRedirectUri ignores case of scheme/host and trailing slash',
      () {
        expect(
          matchesRedirectUri('MyApp://Callback?code=1', 'myapp://callback'),
          isTrue,
        );
        expect(
          matchesRedirectUri('https://app.test/cb/?a=1', 'https://app.test/cb'),
          isTrue,
        );
        expect(
          matchesRedirectUri('myapp://other?code=1', 'myapp://callback'),
          isFalse,
        );
        expect(
          matchesRedirectUri('https://app.test/CB', 'https://app.test/cb'),
          isFalse,
        );
      },
    );

    test('isSecureEndpoint: https, or http only to loopback hosts', () {
      expect(isSecureEndpoint('https://idp.test/authorize'), isTrue);
      expect(isSecureEndpoint('http://localhost:4000/authorize'), isTrue);
      expect(isSecureEndpoint('http://10.0.2.2:4000/authorize'), isTrue);
      expect(isSecureEndpoint('http://idp.test/authorize'), isFalse);
      expect(isSecureEndpoint('http://localhost@evil.test/authorize'), isFalse);
      expect(isSecureEndpoint('myapp://authorize'), isFalse);
    });
  });

  group('pkce', () {
    test('S256 of the RFC 7636 example verifier', () {
      expect(
        sha256Base64Url('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('a generated pair is 43 url-safe characters and never repeats', () {
      final a = PkcePair.generate();
      final b = PkcePair.generate();
      expect(a.codeVerifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(a.codeChallenge, sha256Base64Url(a.codeVerifier));
      expect(a.codeChallengeMethod, 'S256');
      expect(a.codeVerifier, isNot(b.codeVerifier));
    });
  });

  group('id_token', () {
    // Payload {"sub":"1","name":"Añá"} with non-ASCII text.
    const token = 'eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIiwibmFtZSI6IkHDscOhIn0.x';

    test('decodes UTF-8 claims without verifying the signature', () {
      expect(decodeIdToken(token), {'sub': '1', 'name': 'Añá'});
    });

    test('rejects malformed tokens', () {
      for (final bad in ['abc', 'a.b', 'a.!!!.c', 'a.WzFd.c']) {
        expect(
          () => decodeIdToken(bad),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              AuthErrorCode.providerError,
            ),
          ),
        );
      }
    });

    test('validates issuer, audience, nonce and expiry', () {
      final now = DateTime.utc(2026, 1, 1);
      final claims = {
        'iss': 'https://idp.test',
        'aud': ['other', 'client-1'],
        'nonce': 'n1',
        'exp': now.millisecondsSinceEpoch ~/ 1000 + 10,
      };
      validateIdTokenClaims(
        claims,
        issuer: 'https://idp.test',
        audience: 'client-1',
        nonce: 'n1',
        now: now,
      );
      void fails(void Function() check) =>
          expect(check, throwsA(isA<AuthException>()));
      fails(
        () => validateIdTokenClaims(
          claims,
          issuer: 'https://evil.test',
          now: now,
        ),
      );
      fails(
        () => validateIdTokenClaims(claims, audience: 'client-2', now: now),
      );
      fails(() => validateIdTokenClaims(claims, nonce: 'n2', now: now));
      // 60 s of tolerance, then expired.
      validateIdTokenClaims(claims, now: now.add(const Duration(seconds: 60)));
      fails(
        () => validateIdTokenClaims(
          claims,
          now: now.add(const Duration(seconds: 80)),
        ),
      );
    });
  });
}
