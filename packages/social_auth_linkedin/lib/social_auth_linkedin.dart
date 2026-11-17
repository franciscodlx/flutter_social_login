/// Sign In with LinkedIn using OpenID Connect, in the system browser.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult;

export 'src/linkedin.dart';
