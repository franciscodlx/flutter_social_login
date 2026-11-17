import 'errors.dart';

enum EntraFlow { signIn, signUp, resetPassword }

class EntraProfile {
  const EntraProfile({required this.id, this.email, this.name});

  /// `oid` (or `sub`) of the id_token.
  final String id;
  final String? email;
  final String? name;
}

class EntraTokens {
  const EntraTokens({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
    this.scope,
    this.idTokenClaims,
    this.profile,
  });

  final String accessToken;

  /// Only with the `openid` scope.
  final String? idToken;

  /// Only with the `offline_access` scope.
  final String? refreshToken;

  /// Lifetime of the access token in seconds.
  final int? expiresIn;
  final String? scope;

  /// Unverified id_token claims (verify the signature on your backend).
  final Map<String, dynamic>? idTokenClaims;
  final EntraProfile? profile;
}

/// What the flow needs next. `switch` over it to drive the UI.
sealed class EntraStep {
  const EntraStep();
}

/// A step that carries Entra's opaque continuation token: pass the whole step
/// back to the next method.
sealed class EntraContinuation extends EntraStep {
  const EntraContinuation({
    required this.flow,
    required this.username,
    required this.continuationToken,
  });

  final EntraFlow flow;
  final String username;
  final String continuationToken;
}

/// A one-time passcode was sent; ask for it and call `submitCode`.
final class CodeRequiredStep extends EntraContinuation {
  const CodeRequiredStep({
    required super.flow,
    required super.username,
    required super.continuationToken,
    this.channel,
    this.sentTo,
    this.codeLength,
  });

  /// `email` or `sms`.
  final String? channel;

  /// Masked destination, e.g. `c***r@co**o.com`.
  final String? sentTo;
  final int? codeLength;
}

/// Ask for the password and call `submitPassword`.
final class PasswordRequiredStep extends EntraContinuation {
  const PasswordRequiredStep({
    required super.flow,
    required super.username,
    required super.continuationToken,
  });
}

/// The user flow needs more attributes; call `submitAttributes`.
final class AttributesRequiredStep extends EntraContinuation {
  const AttributesRequiredStep({
    required super.username,
    required super.continuationToken,
    required this.requiredAttributes,
  }) : super(flow: EntraFlow.signUp);

  final List<RequiredAttribute> requiredAttributes;
}

/// The code was accepted; ask for the new password and call
/// `submitNewPassword`.
final class NewPasswordRequiredStep extends EntraContinuation {
  const NewPasswordRequiredStep({
    required super.username,
    required super.continuationToken,
  }) : super(flow: EntraFlow.resetPassword);
}

/// Entra cannot finish this flow through the API (for example MFA or a
/// sign-in method the app did not declare). Continue with
/// `signInWithBrowser`.
final class BrowserRequiredStep extends EntraStep {
  const BrowserRequiredStep({required this.flow, required this.username});

  final EntraFlow flow;
  final String username;
}

final class SignedInStep extends EntraStep {
  const SignedInStep(this.tokens);

  final EntraTokens tokens;
}
