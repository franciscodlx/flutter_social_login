/// OAuth 2.0 authorization code + PKCE in the system browser, shared by every
/// social login plugin of the family.
library;

export 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart'
    show AuthErrorCode, AuthException;

export 'src/authorize.dart';
export 'src/id_token.dart';
export 'src/pkce.dart';
export 'src/provider.dart';
export 'src/provider_login_controller.dart';
export 'src/token.dart';
export 'src/url.dart'
    show
        appendParams,
        isSecureEndpoint,
        matchesRedirectUri,
        parseRedirectParams;
