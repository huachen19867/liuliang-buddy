/// Restores only an opaque credential pair issued by the official website.
///
/// `savedAt` is the time of a local capture, not a carrier expiry time. Neither
/// its age nor a missing timestamp proves that the official session expired.
/// The next official query must decide whether this backup is still usable.
Map<String, dynamic>? normalizeBroadnetSession(Object? candidate) {
  if (candidate is! Map) return null;
  final phoneInfo = candidate['phoneInfo'];
  final sessionId = candidate['sessionId'];
  if (phoneInfo is! String ||
      sessionId is! String ||
      phoneInfo.trim().isEmpty ||
      sessionId.trim().isEmpty ||
      phoneInfo.length > 20000 ||
      sessionId.length > 20000) {
    return null;
  }
  return {
    'phoneInfo': phoneInfo,
    'sessionId': sessionId,
    if (candidate['savedAt'] is String) 'savedAt': candidate['savedAt'],
  };
}

/// Records a fresh official-page capture, including changes to phoneInfo when
/// the opaque sessionId is unchanged. This does not refresh a server session or
/// establish successful authentication; only an official response can do that.
Map<String, dynamic>? captureBroadnetSession(
  Object? candidate, {
  required DateTime capturedAt,
}) {
  final session = normalizeBroadnetSession(candidate);
  if (session == null) return null;
  return {...session, 'savedAt': capturedAt.toIso8601String()};
}

/// Capture times may change during a refresh; only the credential pair defines
/// whether a foreground login superseded an in-flight background query.
bool sameBroadnetSession(Object? left, Object? right) {
  final a = normalizeBroadnetSession(left);
  final b = normalizeBroadnetSession(right);
  if (a == null || b == null) return a == null && b == null;
  return a['sessionId'] == b['sessionId'] && a['phoneInfo'] == b['phoneInfo'];
}
