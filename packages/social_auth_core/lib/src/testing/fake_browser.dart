// Only imported from tests, through package:social_auth_core/testing.dart.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

/// Stand-in for the system browser: answers each session with [respond],
/// or throws [failure].
class FakeBrowser extends SocialAuthCorePlatform
    with MockPlatformInterfaceMixin {
  FakeBrowser();

  /// Approves, echoing `state`, with [params] added to the redirect.
  FakeBrowser.approving([
    Map<String, String> params = const {'code': 'the-code'},
  ]) {
    respond = (url, callbackUrl) {
      final state = Uri.parse(url).queryParameters['state'] ?? '';
      final query = Uri(queryParameters: {...params, 'state': state}).query;
      return '$callbackUrl?$query';
    };
  }

  String Function(String url, String callbackUrl)? respond;
  Object? failure;
  final calls = <({String url, String callbackUrl, bool ephemeral})>[];
  bool cancelled = false;

  Map<String, String> get sentParams =>
      Uri.parse(calls.last.url).queryParameters;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> openAuthSession({
    required String url,
    required String callbackUrl,
    bool prefersEphemeralSession = false,
  }) async {
    calls.add((
      url: url,
      callbackUrl: callbackUrl,
      ephemeral: prefersEphemeralSession,
    ));
    if (failure != null) {
      throw failure!;
    }
    return respond!(url, callbackUrl);
  }

  @override
  Future<void> cancelAuthSession() async => cancelled = true;
}

/// Builds an unsigned JWT with [claims], for id_token tests.
String makeJwt(Map<String, Object?> claims) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'RS256'})}.${encode(claims)}.signature';
}
