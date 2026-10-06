import 'dart:math';

/// Per-account query identity. Tokens identify a local attempt, never a user.
class QueryRoundRegistry {
  QueryRoundRegistry()
    : _nonce = Random.secure().nextInt(1 << 32).toRadixString(36);

  final String _nonce;
  final Map<String, String> _epochs = {};
  int _sequence = 0;

  String begin(String accountId) {
    final epoch = 'q${_nonce}_${(++_sequence).toRadixString(36)}';
    _epochs[accountId] = epoch;
    return epoch;
  }

  String? current(String accountId) => _epochs[accountId];

  bool isCurrent(String accountId, String? queryEpoch) =>
      queryEpoch != null && _epochs[accountId] == queryEpoch;

  /// A late attempt cannot finish a newer attempt for the same account.
  bool finish(String accountId, String queryEpoch) {
    if (!isCurrent(accountId, queryEpoch)) return false;
    _epochs.remove(accountId);
    return true;
  }

  void cancel(String accountId) => _epochs.remove(accountId);

  // Keep the sequence so a cancelled token can never become current again.
  void clear() => _epochs.clear();
}
