/// Sign in with Twitch using OpenID Connect, in the system browser.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult;

export 'src/twitch.dart';
