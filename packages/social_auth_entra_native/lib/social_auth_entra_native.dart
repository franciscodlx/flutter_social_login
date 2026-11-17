/// Microsoft Entra External ID native authentication: sign-in, sign-up and
/// password reset with your own screens, plus the browser flow as fallback.
library;

export 'package:social_auth_core/social_auth_core.dart'
    show AuthErrorCode, AuthException;

export 'src/client.dart';
export 'src/errors.dart';
export 'src/steps.dart';
