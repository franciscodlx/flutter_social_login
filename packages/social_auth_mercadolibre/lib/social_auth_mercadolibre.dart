/// Sign in with Mercado Libre: authorization code + PKCE in the system
/// browser, exchanged by your backend.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult;

export 'src/mercadolibre.dart';
