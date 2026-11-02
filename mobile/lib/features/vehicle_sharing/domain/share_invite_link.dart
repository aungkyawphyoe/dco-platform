/// A vehicle share code encoded as a QR/deep link
/// (`dco://vehicle/share/join?code=ABCD1234`).
///
/// The owner's QR panel and the operating system's camera both produce the
/// same URI, so the in-app scanner and the deep-link handler share this
/// parser. A bare 8-character code is also accepted, which lets people paste
/// a code from a message.
class ShareInviteLink {
  const ShareInviteLink(this.code);

  static const scheme = 'dco';
  static const host = 'vehicle';
  static const path = '/share/join';

  /// In-app route that shows the join screen.
  static const routePath = '/vehicle/share/join';

  /// Upper-cased share code, always 8 alphanumeric characters.
  final String code;

  static final _codePattern = RegExp(r'^[A-Za-z0-9]{8}$');

  /// Parses a scanned payload, a deep link, or a bare share code.
  /// Returns null when the value is not a share link/code.
  static ShareInviteLink? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.isNotEmpty) {
      if (uri.scheme.toLowerCase() != scheme) return null;
      if (uri.host.toLowerCase() != host) return null;
      if (_normalizePath(uri.path) != path) return null;
      return _fromCode(uri.queryParameters['code']);
    }

    return _fromCode(value);
  }

  /// Parses only platform deep links, never bare text. In-app router locations
  /// have no scheme, so this returns null for them.
  static ShareInviteLink? fromDeepLink(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme) return null;
    return tryParse(uri.toString());
  }

  static ShareInviteLink? _fromCode(String? raw) {
    final value = raw?.trim() ?? '';
    if (!_codePattern.hasMatch(value)) return null;
    return ShareInviteLink(value.toUpperCase());
  }

  static String _normalizePath(String path) {
    if (path.isEmpty || path == '/') return path;
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }

  /// The QR/deep-link payload handed out by the owner.
  Uri toUri() => Uri(
    scheme: scheme,
    host: host,
    path: path,
    queryParameters: {'code': code},
  );

  /// GoRouter location that opens the join screen with [code] filled in.
  String get routeLocation =>
      Uri(path: routePath, queryParameters: {'code': code}).toString();

  @override
  bool operator ==(Object other) =>
      other is ShareInviteLink && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => toUri().toString();
}
