/// Sign in with GitHub, Discord, Slack and Strava in the system browser.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show
        AuthErrorCode,
        AuthException,
        ProviderConfig,
        ProviderLogin,
        ProviderLoginController,
        SignInOptions,
        SignInResult;

export 'src/login.dart';
export 'src/presets.dart';
