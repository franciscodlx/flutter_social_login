import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'auth_exception.dart';

/// What a platform contributes: a browser session the app cannot read, which
/// ends when the browser reaches the callback URL.
abstract class SocialAuthCorePlatform extends PlatformInterface {
  SocialAuthCorePlatform() : super(token: _token);

  static final Object _token = Object();

  static SocialAuthCorePlatform _instance = _UnsupportedPlatform();

  /// The implementation in use. Platform packages set it when they register.
  static SocialAuthCorePlatform get instance => _instance;

  static set instance(SocialAuthCorePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Whether a sign-in can be presented on this device.
  Future<bool> isAvailable();

  /// Opens [url] in the system browser and completes with the full URL the
  /// browser was sent to once it matches [callbackUrl].
  ///
  /// Throws an [AuthException] with [AuthErrorCode.cancelled] when the user
  /// closes the browser.
  Future<String> openAuthSession({
    required String url,
    required String callbackUrl,
    bool prefersEphemeralSession = false,
  });

  /// Dismisses the browser of the sign-in in progress, which then fails with
  /// [AuthErrorCode.cancelled].
  Future<void> cancelAuthSession();
}

class _UnsupportedPlatform extends SocialAuthCorePlatform {
  static const _error = AuthException(
    AuthErrorCode.notSupported,
    'social_auth_core has no implementation for this platform',
  );

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String> openAuthSession({
    required String url,
    required String callbackUrl,
    bool prefersEphemeralSession = false,
  }) => Future.error(_error);

  @override
  Future<void> cancelAuthSession() async {}
}
