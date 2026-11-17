import 'package:flutter/services.dart';

/// Error codes shared by every plugin of the family, so apps handle failures
/// the same way no matter the provider.
enum AuthErrorCode {
  /// The user closed the browser or rejected the request.
  cancelled('CANCELLED'),

  /// A request to the provider could not be made.
  network('NETWORK'),

  /// The app passed something the flow cannot work with.
  invalidConfig('INVALID_CONFIG'),

  /// The provider answered with an error or an unusable response.
  providerError('PROVIDER_ERROR'),

  /// The platform cannot run the sign-in (no browser, unsupported OS).
  notSupported('NOT_SUPPORTED');

  const AuthErrorCode(this.value);

  /// Wire value, the same string the React Native family uses.
  final String value;

  static AuthErrorCode? tryParse(String? value) {
    for (final code in values) {
      if (code.value == value) {
        return code;
      }
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(
    this.code,
    this.message, {
    this.providerError,
    this.providerErrorDescription,
    this.status,
    this.cause,
  });

  /// Normalizes anything thrown by a platform implementation or an HTTP call.
  factory AuthException.from(
    Object error, {
    AuthErrorCode fallback = AuthErrorCode.providerError,
  }) {
    if (error is AuthException) {
      return error;
    }
    if (error is PlatformException) {
      return AuthException(
        AuthErrorCode.tryParse(error.code) ?? fallback,
        error.message ?? 'Authentication failed',
        cause: error,
      );
    }
    return AuthException(fallback, 'Authentication failed', cause: error);
  }

  final AuthErrorCode code;
  final String message;

  /// `error` returned by the provider (RFC 6749 §4.1.2.1 / §5.2), if any.
  final String? providerError;

  /// `error_description` returned by the provider, if any.
  final String? providerErrorDescription;

  /// HTTP status of the failed token/userinfo request, if any.
  final int? status;
  final Object? cause;

  bool get isCancelled => code == AuthErrorCode.cancelled;

  @override
  String toString() => 'AuthException(${code.value}): $message';
}
