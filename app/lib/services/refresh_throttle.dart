/// Limits repeated reloads while leaving an official login return immediately
/// retryable. Account IDs, rather than carriers, are the throttle keys.
class RefreshThrottle {
  final Map<String, DateTime> _lastRequests = {};

  bool blocks(String accountId, DateTime now) {
    final last = _lastRequests[accountId];
    if (last == null) return false;
    final elapsed = now.difference(last);
    return !elapsed.isNegative && elapsed < const Duration(seconds: 30);
  }

  void started(String accountId, DateTime now) {
    _lastRequests[accountId] = now;
  }

  void loginOrLoadFailed(String accountId) {
    _lastRequests.remove(accountId);
  }

  void clear() => _lastRequests.clear();
}
