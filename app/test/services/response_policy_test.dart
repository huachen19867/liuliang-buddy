import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/response_policy.dart';

void main() {
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
