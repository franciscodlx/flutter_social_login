import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final Random _random = Random.secure();

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// [byteLength] bytes from the platform CSPRNG, base64url without padding.
String randomBase64Url(int byteLength) {
  final bytes = Uint8List(byteLength.clamp(1, 1024));
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return _base64Url(bytes);
}

/// SHA-256 of [input] (UTF-8), base64url without padding.
String sha256Base64Url(String input) =>
    _base64Url(sha256.convert(utf8.encode(input)).bytes);

/// A PKCE verifier and its S256 challenge (RFC 7636).
class PkcePair {
  const PkcePair({required this.codeVerifier, required this.codeChallenge});

  /// A fresh pair: 32 random bytes → 43-character verifier.
  factory PkcePair.generate() {
    final verifier = randomBase64Url(32);
    return PkcePair(
      codeVerifier: verifier,
      codeChallenge: sha256Base64Url(verifier),
    );
  }

  final String codeVerifier;
  final String codeChallenge;
  String get codeChallengeMethod => 'S256';
}
