const _allowedImageMimes = {
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp',
};

const _allowedVideoMimes = {
  'video/mp4', 'video/quicktime', 'video/x-msvideo',
  'video/webm', 'video/3gpp', 'video/avi', 'video/mkv',
};

const _allowedAudioMimes = {
  'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg',
  'audio/aac', 'audio/flac', 'audio/m4a', 'audio/mp4', 'audio/webm',
};

const _extensionToMime = {
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
  '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp',
  '.mp4': 'video/mp4', '.mov': 'video/quicktime', '.avi': 'video/x-msvideo',
  '.webm': 'video/webm', '.mkv': 'video/mkv', '.3gp': 'video/3gpp',
  '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.ogg': 'audio/ogg',
  '.aac': 'audio/aac', '.flac': 'audio/flac', '.m4a': 'audio/m4a',
};

const _trustedDomains = [
  'witalk.in',
  'witalk-files.blr1.cdn.digitaloceanspaces.com',
  'witalk-files.blr1.digitaloceanspaces.com',
];

final _dangerousSchemes = RegExp(r'^(javascript|data|vbscript|blob|file):', caseSensitive: false);
final _localIpPattern = RegExp(r'^(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+)$');

/// Returns a validated MIME type or null if the file is not allowed.
///
/// [expectedCategory]: 'image', 'video', or 'audio'
String? getValidatedMime(String filePath, String? pickerMime, String expectedCategory) {
  final Set<String> allowed;
  switch (expectedCategory) {
    case 'image':
      allowed = _allowedImageMimes;
    case 'video':
      allowed = _allowedVideoMimes;
    case 'audio':
      allowed = _allowedAudioMimes;
    default:
      return null;
  }

  // 1. Use picker MIME if allowed
  if (pickerMime != null && allowed.contains(pickerMime)) return pickerMime;

  // 2. Derive MIME from extension
  final lastDot = filePath.lastIndexOf('.');
  if (lastDot != -1) {
    final ext = filePath.substring(lastDot).toLowerCase();
    final derived = _extensionToMime[ext];
    if (derived != null && allowed.contains(derived)) return derived;
  }

  // 3. iOS HEIC and similar: picker MIME starts with expected category
  if (pickerMime != null && pickerMime.startsWith('$expectedCategory/')) return pickerMime;

  return null;
}

/// Validates and sanitizes a file URL from the upload server.
/// Returns the URL if it belongs to a trusted domain, null if suspicious.
String? sanitizeFileUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;

  final trimmed = url.trim();

  if (_dangerousSchemes.hasMatch(trimmed)) return null;
  if (!trimmed.startsWith('https://') && !trimmed.startsWith('http://')) return null;

  try {
    final uri = Uri.parse(trimmed);
    final hostname = uri.host.toLowerCase();

    for (final domain in _trustedDomains) {
      if (hostname == domain || hostname.endsWith('.$domain')) return trimmed;
    }

    if (uri.scheme == 'http' && _localIpPattern.hasMatch(hostname)) return trimmed;

    return null;
  } catch (_) {
    return null;
  }
}
