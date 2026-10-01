import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/response_policy.dart';

void main() {
  test(
    'Unicom session expiry requires only an explicit false flag and 2xx',
    () {
      expect(isUnicomSessionExpired({'isLogin': false}, 200), isTrue);
      for (final data in <Map<String, dynamic>>[
        {},
        {'isLogin': true},
        {'isLogin': 'false'},
        {'isLogin': 0},
        {'isLogin': false, 'userInfo': {}},
      ]) {
        expect(isUnicomSessionExpired(data, 200), isFalse);
      }
      for (final status in <int?>[null, 0, 199, 300, 401, 500]) {
        expect(isUnicomSessionExpired({'isLogin': false}, status), isFalse);
      }
    },
  );

  test('accepts verified plaintext success before decoded event arrives', () {
    expect(
      shouldApplyBroadnetResponse(
        stage: 'raw',
        parsedStatus: QueryStatus.success,
        currentStatus: QueryStatus.loading,
        httpStatus: 200,
      ),
      isTrue,
    );
  });

  test('raw event cannot replace a success already shown', () {
    for (final status in [
      QueryStatus.success,
      QueryStatus.authExpired,
      QueryStatus.error,
    ]) {
      expect(
        shouldApplyBroadnetResponse(
          stage: 'raw',
          parsedStatus: status,
          currentStatus: QueryStatus.success,
          httpStatus: 200,
        ),
        isFalse,
      );
    }
  });

  test('raw ciphertext or unknown structure cannot clear current query', () {
    expect(
      shouldApplyBroadnetResponse(
        stage: 'raw',
        parsedStatus: QueryStatus.error,
        currentStatus: QueryStatus.loading,
        httpStatus: 200,
      ),
      isFalse,
    );
    expect(
      shouldApplyBroadnetResponse(
        stage: 'unknown',
        parsedStatus: QueryStatus.success,
        currentStatus: QueryStatus.loading,
        httpStatus: 200,
      ),
      isFalse,
    );
  });

  test('raw authentication and HTTP failures remain visible during query', () {
    expect(
      shouldApplyBroadnetResponse(
        stage: 'raw',
        parsedStatus: QueryStatus.authExpired,
        currentStatus: QueryStatus.loading,
        httpStatus: 200,
      ),
      isTrue,
    );
    expect(
      shouldApplyBroadnetResponse(
        stage: 'raw',
        parsedStatus: QueryStatus.error,
        currentStatus: QueryStatus.loading,
        httpStatus: 503,
      ),
      isTrue,
    );
  });
}
