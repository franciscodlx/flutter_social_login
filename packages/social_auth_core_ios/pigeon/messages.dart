import 'package:pigeon/pigeon.dart';

// The interface between Dart and the host platform. After editing, run
//   dart run pigeon --input pigeon/messages.dart
@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'social_auth_core_ios',
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'ios/social_auth_core_ios/Sources/social_auth_core_ios/Messages.g.swift',
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
