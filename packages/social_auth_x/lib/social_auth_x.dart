/// Sign in with X (Twitter): OAuth 2.0 + PKCE in the system browser.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult,
        TokenResponse;

export 'src/x.dart';
