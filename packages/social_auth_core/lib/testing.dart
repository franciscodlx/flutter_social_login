/// Test helpers: drive `signIn` without a browser or a device.
///
/// ```dart
/// final browser = FakeBrowser.approving();
/// SocialAuthCorePlatform.instance = browser;
/// ```
library;

export 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart'
    show SocialAuthCorePlatform;

export 'src/testing/fake_browser.dart';
