import 'dart:convert';

import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

const _malformed = AuthException(
  AuthErrorCode.providerError,
  'Malformed id_token',
);

/// Decodes the payload of a JWT **without verifying its signature**.
/// Use the claims for display; verify the signature on your backend before
/// trusting them.
Map<String, dynamic> decodeIdToken(String idToken) {
  final parts = idToken.split('.');
  if (parts.length != 3 || parts[1].isEmpty) {
    throw _malformed;
  }
  try {
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (claims is Map<String, dynamic>) {
      return claims;
    }
  } on Object {
    // Reported below.
  }
  throw _malformed;
}

/// Checks the claims an app can check on-device: `iss`, `aud`, `exp` and
/// `nonce` (OpenID Connect Core §3.1.3.7). The signature is NOT verified here.
/// A null expectation is skipped.
void validateIdTokenClaims(
  Map<String, dynamic> claims, {
  String? issuer,
  String? audience,
  String? nonce,
  Duration clockTolerance = const Duration(seconds: 60),
  DateTime? now,
}) {
  Never fail(String reason) => throw AuthException(
    AuthErrorCode.providerError,
    'Invalid id_token: $reason',
  );

  if (issuer != null && claims['iss'] != issuer) {
    fail('unexpected issuer');
  }
  if (audience != null) {
    final aud = claims['aud'];
    final audiences = aud is List ? aud : [aud];
    if (!audiences.contains(audience)) {
      fail('unexpected audience');
    }
  }
  if (nonce != null && claims['nonce'] != nonce) {
    fail('nonce mismatch');
  }
  final exp = claims['exp'];
  if (exp is num) {
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).toInt(),
      isUtc: true,
    );
    if ((now ?? DateTime.now()).toUtc().isAfter(expiry.add(clockTolerance))) {
      fail('token expired');
    }
  }
}
