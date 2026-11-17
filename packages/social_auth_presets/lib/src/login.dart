import 'package:http/http.dart' as http;
import 'package:social_auth_core/social_auth_core.dart';

import 'presets.dart';

/// Login of a [Preset]: the core's sign-in plus the RFC 9207 issuer check.
class PresetLogin extends ProviderLogin<PresetProfile> {
  PresetLogin(this.preset, super.provider, {super.httpClient});

  final Preset preset;

  @override
  Future<SignInResult<PresetProfile>> signIn(SignInOptions options) async {
    final result = await super.signIn(options);
    // RFC 9207: a response carrying another issuer was not meant for us.
    final expected = preset.redirectIssuer;
    final iss = result.params['iss'];
    if (expected != null && iss != null && iss != expected) {
      throw const AuthException(
        AuthErrorCode.providerError,
        'The response came from an unexpected issuer',
      );
    }
    return result;
  }
}

/// Builds the login of [preset]. The named arguments replace fields of its
/// config, e.g. `defaultScopes: ['identify']` or a test server's
/// `authorizationEndpoint`.
PresetLogin createPresetLogin(
  Preset preset, {
  String? authorizationEndpoint,
  List<String>? defaultScopes,
  bool? usePkce,
  Map<String, String>? extraAuthParams,
  http.Client? httpClient,
}) => PresetLogin(
  preset,
  preset.config.copyWith(
    authorizationEndpoint: authorizationEndpoint,
    defaultScopes: defaultScopes,
    usePkce: usePkce,
    extraAuthParams: extraAuthParams,
  ),
  httpClient: httpClient,
);

final githubLogin = createPresetLogin(githubPreset);
final discordLogin = createPresetLogin(discordPreset);
final slackLogin = createPresetLogin(slackPreset);
final stravaLogin = createPresetLogin(stravaPreset);
