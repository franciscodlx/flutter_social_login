import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

class _Fake extends SocialAuthCorePlatform with MockPlatformInterfaceMixin {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> openAuthSession({
    required String url,
    required String callbackUrl,
    bool prefersEphemeralSession = false,
  }) async => '$callbackUrl?code=1';

  @override
  Future<void> cancelAuthSession() async {}
}

void main() {
  test(
    'without an implementation the platform reports NOT_SUPPORTED',
    () async {
      expect(await SocialAuthCorePlatform.instance.isAvailable(), isFalse);
      await expectLater(
        SocialAuthCorePlatform.instance.openAuthSession(
          url: 'https://idp.test',
          callbackUrl: 'myapp://callback',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.notSupported,
          ),
        ),
      );
    },
  );

  test('an implementation can register itself', () async {
    SocialAuthCorePlatform.instance = _Fake();
    expect(await SocialAuthCorePlatform.instance.isAvailable(), isTrue);
  });

  test('AuthException.from maps platform error codes', () {
    final cancelled = AuthException.from(
      PlatformException(code: 'CANCELLED', message: 'closed'),
    );
    expect(cancelled.code, AuthErrorCode.cancelled);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.message, 'closed');

    final unknown = AuthException.from(PlatformException(code: 'boom'));
    expect(unknown.code, AuthErrorCode.providerError);

    final network = AuthException.from(
      StateError('x'),
      fallback: AuthErrorCode.network,
    );
    expect(network.code, AuthErrorCode.network);
    expect(AuthErrorCode.tryParse('NOT_SUPPORTED'), AuthErrorCode.notSupported);
  });
}
