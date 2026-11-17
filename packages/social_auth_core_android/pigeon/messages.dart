import 'package:pigeon/pigeon.dart';

// The interface between Dart and the host platform. After editing, run
//   dart run pigeon --input pigeon/messages.dart
@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'social_auth_core_android',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/dev/franciscodlx/social_auth_core_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.franciscodlx.social_auth_core_android',
    ),
  ),
)
@HostApi()
abstract class AuthSessionApi {
  /// Whether a sign-in can be presented on this device.
  bool isAvailable();

  /// Opens [url] in the system browser. Completes with the URL the browser
  /// was redirected to once it matches [callbackUrl]; fails with the error
  /// codes CANCELLED, NOT_SUPPORTED or INVALID_CONFIG.
  @async
  String open(String url, String callbackUrl, bool prefersEphemeralSession);

  /// Dismisses the browser of the sign-in in progress.
  void cancel();
}
