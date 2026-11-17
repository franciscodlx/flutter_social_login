import 'package:flutter/foundation.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'src/messages.g.dart';

/// The Android implementation of [SocialAuthCorePlatform].
class SocialAuthCoreAndroid extends SocialAuthCorePlatform {
  SocialAuthCoreAndroid({@visibleForTesting AuthSessionApi? api})
    : _api = api ?? AuthSessionApi();

  final AuthSessionApi _api;

  /// Called by Flutter when the app starts on this platform.
  static void registerWith() {
    SocialAuthCorePlatform.instance = SocialAuthCoreAndroid();
  }

  @override
  Future<bool> isAvailable() => _api.isAvailable();

  @override
  Future<String> openAuthSession({
    required String url,
    required String callbackUrl,
    bool prefersEphemeralSession = false,
  }) async {
    try {
      return await _api.open(url, callbackUrl, prefersEphemeralSession);
    } catch (error) {
      // The host reports CANCELLED / NOT_SUPPORTED / INVALID_CONFIG as the
      // code of a PlatformException.
      throw AuthException.from(error);
    }
  }

  @override
  Future<void> cancelAuthSession() => _api.cancel();
}
