import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

// Synthetic fixtures based on the public official E5 template, not accounts.
void main() {
  Map<String, dynamic> response(
    Object? remaining, {
    Map<String, dynamic> extra = const {},
  }) => {
    'resource': {
      'successFlow': true,
      'flowFlag': true,
      'remainFlow': remaining,
      'overFlow': 0,
      ...extra,
    },
  };
  test(
    'E5 MB balance remains a package summary and never a general allowance',
    () {
      final snapshot = parseUnicomWeb(
        response('1536'),
        queriedAt: DateTime.utc(2026, 9, 30),
      );
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.buckets.single.remainingBytes, 1536 * 1024 * 1024);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(summarizeTraffic(snapshot)?.label, '套餐余量');
      expect(summarizeTraffic(snapshot)?.remainingBytes, 1536 * 1024 * 1024);
    },
  );
  test(
    'finite zero is valid; missing, negative, invalid and infinity cannot become zero',
    () {
      expect(parseUnicomWeb(response(0)).status, QueryStatus.success);
      for (final raw in [null, '', 'NaN', '-1', 'Infinity', '1e99', true]) {
        expect(
          parseUnicomWeb(response(raw)).status,
          QueryStatus.error,
          reason: '$raw',
        );
      }
    },
  );
  test(
    'failed flow, absent flow and unlimited usage are never shown as remaining',
    () {
      for (final extra in [
        {'successFlow': false},
        {'flowFlag': false},
        {'hasNolimitedFlow': true, 'usedFlow': 300},
        {'hasNolimitedFlow': 1, 'usedFlow': 300},
        {'hasNolimitedFlow': 'false', 'usedFlow': 300},
      ]) {
        final snapshot = parseUnicomWeb(response(500, extra: extra));
        expect(snapshot.status, QueryStatus.error);
        expect(snapshot.buckets, isEmpty);
        expect(summarizeTraffic(snapshot), isNull);
      }
    },
  );
  test(
    'official overage has priority over remaining, without becoming a general warning',
    () {
      final snapshot = parseUnicomWeb(response(500, extra: {'overFlow': 12}));
      expect(snapshot.buckets.single.remainingBytes, 0);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(snapshot.message, contains('超出'));
    },
  );
  test(
    'HTTP and explicit expired-session errors reject a leftover resource',
    () {
      expect(
        parseUnicomWeb(response(500), httpStatus: 401).status,
        QueryStatus.authExpired,
      );
      expect(
        parseUnicomWeb(response(500), httpStatus: 500).status,
        QueryStatus.error,
      );
      expect(
        parseUnicomWeb({...response(500), 'message': '登录已失效'}).status,
        QueryStatus.authExpired,
      );
    },
  );
}
