import 'package:social_auth_core/social_auth_core.dart';

/// An attribute the sign-up user flow still needs.
class RequiredAttribute {
  const RequiredAttribute({
    required this.name,
    this.type,
    this.required,
    this.regex,
  });

  factory RequiredAttribute.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return RequiredAttribute(
      name: '${json['name']}',
      type: json['type'] as String?,
      required: json['required'] as bool?,
      regex: options is Map ? options['regex'] as String? : null,
    );
  }

  /// Programmable name, e.g. `displayName`.
  final String name;
  final String? type;
  final bool? required;
  final String? regex;

  @override
  bool operator ==(Object other) =>
      other is RequiredAttribute &&
      other.name == name &&
      other.type == type &&
      other.required == required &&
      other.regex == regex;

  @override
  int get hashCode => Object.hash(name, type, required, regex);

  @override
  String toString() => 'RequiredAttribute($name)';
}

/// An error answered by the native authentication API. [providerError] is
/// Entra's `error` (e.g. `user_not_found`, `invalid_grant`) and [suberror]
/// narrows it down (e.g. `invalid_oob_value`, `password_too_weak`).
class EntraAuthException extends AuthException {
  EntraAuthException(
    super.code,
    super.message, {
    Map<String, dynamic> body = const {},
    super.status,
  }) : suberror = body['suberror'] as String?,
       errorCodes = [
         for (final code in body['error_codes'] as List? ?? const [])
           if (code is int) code,
       ],
       invalidAttributes = [
         for (final attribute
             in body['invalid_attributes'] as List? ?? const [])
           if (attribute is Map) '${attribute['name']}',
       ],
       traceId = body['trace_id'] as String?,
       correlationId = body['correlation_id'] as String?,
       super(
         providerError: body['error'] as String?,
         providerErrorDescription: body['error_description'] as String?,
       );

  final String? suberror;
  final List<int> errorCodes;
  final List<String> invalidAttributes;

  /// For support requests to Microsoft.
  final String? traceId;
  final String? correlationId;

  /// `user_not_found`, `invalid_grant:invalid_oob_value`, … for a `switch`.
  String get reason => [
    providerError,
    suberror,
  ].whereType<String>().where((part) => part.isNotEmpty).join(':');

  @override
  String toString() => 'EntraAuthException(${code.value}, $reason): $message';
}
