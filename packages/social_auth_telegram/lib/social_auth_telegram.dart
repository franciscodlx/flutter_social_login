/// Log in with Telegram using OpenID Connect + PKCE, in the system browser.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult;

export 'src/telegram.dart';
