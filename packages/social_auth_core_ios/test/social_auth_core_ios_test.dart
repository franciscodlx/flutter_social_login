import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core_ios/social_auth_core_ios.dart';
import 'package:social_auth_core_ios/src/messages.g.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

class _FakeApi implements AuthSessionApi {
  Object? failure;
  List<Object?>? lastOpen;
  bool cancelled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> open(
    String url,
    String callbackUrl,
    bool prefersEphemeralSession,
  ) async {
    lastOpen = [url, callbackUrl, prefersEphemeralSession];
    if (failure != null) {
      throw failure!;
    }
    return '$callbackUrl?code=abc';
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerWith installs the implementation', () {
    SocialAuthCoreIos.registerWith();
    expect(SocialAuthCorePlatform.instance, isA<SocialAuthCoreIos>());
  });

  test('forwards the session to the host and returns its redirect', () async {
    final api = _FakeApi();
    final platform = SocialAuthCoreIos(api: api);
    expect(await platform.isAvailable(), isTrue);
    final redirect = await platform.openAuthSession(
      url: 'https://idp.test/authorize?x=1',
      callbackUrl: 'myapp://callback',
      prefersEphemeralSession: true,
    );
    expect(redirect, 'myapp://callback?code=abc');
    expect(api.lastOpen, [
      'https://idp.test/authorize?x=1',
      'myapp://callback',
      true,
    ]);
    await platform.cancelAuthSession();
    expect(api.cancelled, isTrue);
  });

  test('host error codes become AuthException codes', () async {
    final api = _FakeApi()
      ..failure = PlatformException(
        code: 'CANCELLED',
        message: 'The user closed the browser',
      );
    await expectLater(
      SocialAuthCoreIos(api: api).openAuthSession(
        url: 'https://idp.test',
        callbackUrl: 'myapp://callback',
      ),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'code', AuthErrorCode.cancelled)
            .having((e) => e.message, 'message', 'The user closed the browser'),
      ),
    );
  });
}
