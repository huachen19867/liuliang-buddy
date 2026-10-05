import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/broadnet_session.dart';

void main() {
  test(
    'foreground credential rotation supersedes an old query but capture time does not',
    () {
      const old = {'phoneInfo': 'phone-old', 'sessionId': 'session'};
      expect(
        sameBroadnetSession(old, {...old, 'savedAt': '2100-01-01'}),
        isTrue,
      );
      expect(
        sameBroadnetSession(old, {...old, 'phoneInfo': 'phone-new'}),
        isFalse,
      );
      expect(
        sameBroadnetSession(old, {...old, 'sessionId': 'new-session'}),
        isFalse,
      );
      expect(sameBroadnetSession(old, null), isFalse);
      expect(sameBroadnetSession(null, null), isTrue);
    },
  );
  test('local timestamp never declares an official session expired', () {
    for (final timestamp in [
      null,
      'invalid',
      '2000-01-01T00:00:00Z',
      '2100-01-01T00:00:00Z',
    ]) {
      final restored = normalizeBroadnetSession({
        'phoneInfo': 'official-phone',
        'sessionId': 'official-session',
        'savedAt': timestamp,
      });
      expect(restored?['sessionId'], 'official-session');
    }
  });

  test('rejects incomplete or oversized pairs without modifying storage', () {
    for (final candidate in [
      null,
      'not a map',
      <String, dynamic>{},
      {'phoneInfo': 'phone'},
      {'phoneInfo': 'phone', 'sessionId': ''},
      {'phoneInfo': ' ', 'sessionId': 'session'},
      {'phoneInfo': 'phone', 'sessionId': 10},
      {'phoneInfo': 'x' * 20001, 'sessionId': 'session'},
      {'phoneInfo': 'phone', 'sessionId': 'x' * 20001},
    ]) {
      expect(normalizeBroadnetSession(candidate), isNull);
    }
    expect(
      normalizeBroadnetSession({
        'phoneInfo': 'x' * 20000,
        'sessionId': 'x' * 20000,
      }),
      isNotNull,
    );
  });

  test('opaque pair is preserved exactly and extra fields are not copied', () {
    final restored = normalizeBroadnetSession({
      'phoneInfo': '  official-phone\n',
      'sessionId': 'official-session==',
      'savedAt': 42,
      'unexpectedToken': 'must-not-copy',
    });
    expect(restored, {
      'phoneInfo': '  official-phone\n',
      'sessionId': 'official-session==',
    });
  });

  test(
    'capture updates phone info and timestamp with unchanged session id',
    () {
      final capturedAt = DateTime.utc(2026, 10, 5);
      final captured = captureBroadnetSession({
        'phoneInfo': 'updated-official-phone',
        'sessionId': 'same-official-session',
        'savedAt': '2000-01-01T00:00:00Z',
      }, capturedAt: capturedAt);
      expect(captured, {
        'phoneInfo': 'updated-official-phone',
        'sessionId': 'same-official-session',
        'savedAt': capturedAt.toIso8601String(),
      });
      expect(captureBroadnetSession(null, capturedAt: capturedAt), isNull);
    },
  );
}
