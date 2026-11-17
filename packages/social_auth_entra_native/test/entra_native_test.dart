import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:social_auth_core/testing.dart';
import 'package:social_auth_entra_native/social_auth_entra_native.dart';

import 'mock_entra.dart';

const contoso = 'https://contoso.ciamlogin.com/contoso.onmicrosoft.com';

T expectStep<T extends EntraStep>(EntraStep step) {
  expect(step, isA<T>());
  return step as T;
}

Matcher throwsEntra({String? reason, AuthErrorCode? code}) => throwsA(
  isA<EntraAuthException>()
      .having((e) => e.reason, 'reason', reason ?? anything)
      .having((e) => e.code, 'code', code ?? anything),
);

void main() {
  late MockEntra entra;
  late EntraNativeAuth auth;

  setUp(() async {
    entra = await MockEntra.start();
    auth = EntraNativeAuth(
      tenantSubdomain: 'mock-tenant',
      clientId: 'mock-entra-client',
      baseUrl: entra.baseUrl,
      pollTimeout: const Duration(seconds: 5),
      httpClient: entra.client,
    );
  });
  tearDown(() => entra.stop());

  List<String> paths() => [for (final call in entra.calls) call.path];

  group('sign-in', () {
    test(
      'email + password: initiate, challenge, token; then profile',
      () async {
        final step = expectStep<SignedInStep>(
          await auth.signIn(username: 'ada@example.com', password: 'Passw0rd!'),
        );
        expect(paths(), [
          '/oauth2/v2.0/initiate',
          '/oauth2/v2.0/challenge',
          '/oauth2/v2.0/token',
        ]);
        expect(entra.calls.first.form, {
          'client_id': 'mock-entra-client',
          'username': 'ada@example.com',
          'challenge_type': 'password redirect',
        });
        expect(entra.calls.last.form, containsPair('grant_type', 'password'));
        expect(
          entra.calls.last.form,
          containsPair('scope', 'openid offline_access'),
        );
        expect(step.tokens.accessToken, startsWith('at-'));
        expect(step.tokens.refreshToken, startsWith('rt-'));
        expect(step.tokens.profile?.email, 'ada@example.com');
        expect(step.tokens.profile?.name, 'Ada Lovelace');
      },
    );

    test('a wrong password is a providerError with Entra details', () async {
      await expectLater(
        auth.signIn(username: 'ada@example.com', password: 'nope'),
        throwsA(
          isA<EntraAuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.providerError)
              .having((e) => e.providerError, 'providerError', 'invalid_grant')
              .having((e) => e.errorCodes, 'errorCodes', [50126])
              .having((e) => e.status, 'status', 400),
        ),
      );
    });

    test('an unknown user is reported as user_not_found', () async {
      await expectLater(
        auth.signIn(username: 'nobody@example.com', password: 'x'),
        throwsEntra(reason: 'user_not_found'),
      );
    });

    test('one-time passcode: wrong code fails, a resent one works', () async {
      final code = expectStep<CodeRequiredStep>(
        await auth.signIn(username: 'otp@example.com'),
      );
      expect(code.flow, EntraFlow.signIn);
      expect(code.channel, 'email');
      expect(code.codeLength, 8);
      expect(code.sentTo, 'o***@e***.com');
      await expectLater(
        auth.submitCode(code, '00000000'),
        throwsEntra(reason: 'invalid_grant:invalid_oob_value'),
      );
      // The failed attempt consumed the token: sign in again and resend.
      final again = expectStep<CodeRequiredStep>(
        await auth.signIn(username: 'otp@example.com'),
      );
      final resent = expectStep<CodeRequiredStep>(await auth.resendCode(again));
      expect(resent.continuationToken, isNot(again.continuationToken));
      expectStep<SignedInStep>(await auth.submitCode(resent, '12345678'));
    });

    test(
      'a password account asked for a code falls back to the browser',
      () async {
        expectStep<BrowserRequiredStep>(
          await auth.signIn(username: 'ada@example.com'),
        );
      },
    );

    test('reports the web fallback when Entra answers redirect', () async {
      final step = expectStep<BrowserRequiredStep>(
        await auth.signIn(username: 'sso@example.com', password: 'x'),
      );
      expect(step.flow, EntraFlow.signIn);
      expect(step.username, 'sso@example.com');
    });
  });

  group('sign-up', () {
    test('password + attributes up front: code, then signed in', () async {
      final code = expectStep<CodeRequiredStep>(
        await auth.signUp(
          username: 'new@example.com',
          password: 'Str0ngPass',
          attributes: {'displayName': 'New User'},
        ),
      );
      expect(
        entra.calls.first.form,
        containsPair('challenge_type', 'oob password redirect'),
      );
      expect(
        entra.calls.first.form,
        containsPair('attributes', '{"displayName":"New User"}'),
      );
      final done = expectStep<SignedInStep>(
        await auth.submitCode(code, '12345678'),
      );
      expect(done.tokens.profile?.email, 'new@example.com');
      expect(done.tokens.profile?.name, 'New User');
      expect(
        entra.calls.last.form,
        containsPair('grant_type', 'continuation_token'),
      );
      // The new account can sign in.
      expectStep<SignedInStep>(
        await auth.signIn(username: 'new@example.com', password: 'Str0ngPass'),
      );
    });

    test('walks through what Entra asks: code, password, attributes', () async {
      final code = expectStep<CodeRequiredStep>(
        await auth.signUp(username: 'steps@example.com'),
      );
      final password = expectStep<PasswordRequiredStep>(
        await auth.submitCode(code, '12345678'),
      );
      final attributes = expectStep<AttributesRequiredStep>(
        await auth.submitPassword(password, 'Str0ngPass'),
      );
      expect(attributes.requiredAttributes, [
        const RequiredAttribute(
          name: 'displayName',
          type: 'string',
          required: true,
        ),
      ]);
      expectStep<SignedInStep>(
        await auth.submitAttributes(attributes, {'displayName': 'Steps'}),
      );
    });

    test('reports an existing account and a weak password', () async {
      await expectLater(
        auth.signUp(username: 'ada@example.com', password: 'Str0ngPass'),
        throwsEntra(reason: 'user_already_exists'),
      );
      await expectLater(
        auth.signUp(username: 'weak@example.com', password: 'short'),
        throwsEntra(reason: 'invalid_grant:password_too_short'),
      );
    });
  });

  group('password reset', () {
    test('code, new password, poll, then signed in with it', () async {
      final code = expectStep<CodeRequiredStep>(
        await auth.resetPassword(username: 'ada@example.com'),
      );
      final next = expectStep<NewPasswordRequiredStep>(
        await auth.submitCode(code, '12345678'),
      );
      expectStep<SignedInStep>(
        await auth.submitNewPassword(next, 'N3wPassword'),
      );
      // in_progress, then succeeded
      expect(paths().where((p) => p.endsWith('poll_completion')), hasLength(2));

      await expectLater(
        auth.signIn(username: 'ada@example.com', password: 'Passw0rd!'),
        throwsA(
          isA<EntraAuthException>().having(
            (e) => e.providerError,
            'providerError',
            'invalid_grant',
          ),
        ),
      );
      expectStep<SignedInStep>(
        await auth.signIn(username: 'ada@example.com', password: 'N3wPassword'),
      );
    });

    test('rejects a weak new password', () async {
      final code = expectStep<CodeRequiredStep>(
        await auth.resetPassword(username: 'ada@example.com'),
      );
      final next = expectStep<NewPasswordRequiredStep>(
        await auth.submitCode(code, '12345678'),
      );
      await expectLater(
        auth.submitNewPassword(next, 'short'),
        throwsEntra(reason: 'invalid_grant:password_too_short'),
      );
    });
  });

  group('tokens, browser fallback and config', () {
    test('refreshes with the refresh token', () async {
      final signedIn = expectStep<SignedInStep>(
        await auth.signIn(username: 'ada@example.com', password: 'Passw0rd!'),
      );
      final tokens = await auth.refresh(signedIn.tokens.refreshToken!);
      expect(tokens.accessToken, isNot(signedIn.tokens.accessToken));
      expect(
        entra.calls.last.form,
        containsPair('grant_type', 'refresh_token'),
      );
      expect(
        entra.calls.last.form,
        containsPair('client_id', 'mock-entra-client'),
      );
    });

    test('signInWithBrowser runs code + PKCE against the tenant', () async {
      final browser = FakeBrowser.approving();
      SocialAuthCorePlatform.instance = browser;
      final tokenRequests = <http.Request>[];
      final browserAuth = EntraNativeAuth(
        tenantSubdomain: 'contoso',
        clientId: 'mock-entra-client',
        httpClient: MockClient((request) async {
          tokenRequests.add(request);
          return http.Response(
            jsonEncode({'access_token': 'at-browser', 'expires_in': 3600}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final tokens = await browserAuth.signInWithBrowser(
        redirectUri: 'miapp://callback',
        loginHint: 'sso@example.com',
      );
      final sent = Uri.parse(browser.calls.single.url);
      expect(
        sent.replace(query: '').toString(),
        '$contoso/oauth2/v2.0/authorize?',
      );
      expect(
        sent.queryParameters,
        containsPair('login_hint', 'sso@example.com'),
      );
      expect(
        sent.queryParameters,
        containsPair('scope', 'openid offline_access'),
      );
      expect(
        sent.queryParameters,
        containsPair('code_challenge_method', 'S256'),
      );
      expect(tokenRequests.single.url.toString(), '$contoso/oauth2/v2.0/token');
      expect(tokens.accessToken, 'at-browser');
    });

    test('maps network failures and bad config', () async {
      final offline = EntraNativeAuth(
        tenantSubdomain: 'contoso',
        clientId: 'mock-entra-client',
        httpClient: MockClient(
          (_) => throw http.ClientException('Network request failed'),
        ),
      );
      await expectLater(
        offline.signIn(username: 'ada@example.com', password: 'x'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.network,
          ),
        ),
      );
      expect(
        () => EntraNativeAuth(tenantSubdomain: '', clientId: ''),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidConfig,
          ),
        ),
      );
      expect(
        EntraNativeAuth(tenantSubdomain: 'contoso', clientId: 'x').baseUrl,
        contoso,
      );

      final wrongClient = EntraNativeAuth(
        tenantSubdomain: 'mock-tenant',
        clientId: 'other',
        baseUrl: entra.baseUrl,
        httpClient: entra.client,
      );
      await expectLater(
        wrongClient.signIn(username: 'ada@example.com', password: 'x'),
        throwsEntra(code: AuthErrorCode.invalidConfig),
      );
    });
  });
}
