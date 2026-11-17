/// Appends [params] to [endpoint], keeping any query string it already has.
/// Null values are skipped.
String appendParams(String endpoint, Map<String, String?> params) {
  final query = params.entries
      .where((entry) => entry.value != null)
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value!)}',
      )
      .join('&');
  if (query.isEmpty) {
    return endpoint;
  }
  final hashAt = endpoint.indexOf('#');
  final base = hashAt == -1 ? endpoint : endpoint.substring(0, hashAt);
  final separator = !base.contains('?')
      ? '?'
      : (base.endsWith('?') || base.endsWith('&'))
      ? ''
      : '&';
  return '$base$separator$query';
}

Map<String, String> _decode(String query) {
  if (query.isEmpty) {
    return {};
  }
  try {
    return Uri.splitQueryString(query);
  } on Object {
    // Malformed percent-encoding: treat the response as empty.
    return {};
  }
}

/// Query and fragment parameters of a redirect URL (query wins on conflict).
Map<String, String> parseRedirectParams(String url) {
  final hashAt = url.indexOf('#');
  final fragment = hashAt == -1 ? '' : url.substring(hashAt + 1);
  final withoutFragment = hashAt == -1 ? url : url.substring(0, hashAt);
  final queryAt = withoutFragment.indexOf('?');
  final query = queryAt == -1 ? '' : withoutFragment.substring(queryAt + 1);
  return {..._decode(fragment), ..._decode(query)};
}

final _parts = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):(//[^/?#]*)?([^?#]*)');

String _normalize(String url) {
  final match = _parts.firstMatch(url);
  if (match == null) {
    return url;
  }
  final scheme = match.group(1)!.toLowerCase();
  final authority = (match.group(2) ?? '').toLowerCase();
  final path = (match.group(3) ?? '').replaceAll(RegExp(r'/+$'), '');
  return '$scheme:$authority$path';
}

/// Whether [url] is a redirect to [redirectUri] (same scheme, host and path).
bool matchesRedirectUri(String url, String redirectUri) =>
    _normalize(url) == _normalize(redirectUri);

/// The lowercased scheme of an absolute URI, or null.
String? schemeOf(String url) => _parts.firstMatch(url)?.group(1)?.toLowerCase();

const _loopbackHosts = {'localhost', '127.0.0.1', '10.0.2.2', '[::1]'};

/// https, or plain http to a loopback host (`10.0.2.2` is the Android
/// emulator's alias for the host machine) so a local test server can be used.
bool isSecureEndpoint(String url) {
  final match = RegExp(
    r'^(https?)://([^/?#]+)',
    caseSensitive: false,
  ).firstMatch(url);
  if (match == null) {
    return false;
  }
  if (match.group(1)!.toLowerCase() == 'https') {
    return true;
  }
  final authority = match.group(2)!;
  final host = authority
      .substring(authority.lastIndexOf('@') + 1)
      .replaceFirst(RegExp(r':\d+$'), '')
      .toLowerCase();
  return _loopbackHosts.contains(host);
}
