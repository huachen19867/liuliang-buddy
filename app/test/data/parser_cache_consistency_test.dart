import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  final queriedAt = DateTime.utc(2026, 10, 6, 1, 2, 3);

  List<CarrierSnapshot> parseAll(
    Object? remaining,
    Object? total, {
    bool withDirected = false,
  }) => [
    parseMobile({
      'data': {
        'resultData': {
          'planRemianFlowInfo': {
            'planRemian': {
              'remainNum': remaining,
              'sumNum': total,
              'unit': 'KB',
            },
            if (withDirected)
              'directionalFlowInfo': {
                'remainNum': '1',
                'sumNum': '2',
                'unit': 'KB',
              },
          },
        },
      },
    }, queriedAt: queriedAt),
    parseBroadnet({
      'status': '000000',
      'data': {
        'intfResultBean': {
          'userResList': [
            {
              'itemName': '通用流量',
              'balance': remaining,
              'highFee': total,
              'unit': 'KB',
            },
            if (withDirected)
              {
                'itemName': '定向流量',
                'balance': '1',
                'highFee': '2',
                'unit': 'KB',
              },
          ],
        },
      },
    }, queriedAt: queriedAt),
    parseBroadnetH5({
      'respCode': '000000',
      'intfResultBean': {
        'userResList': [
          {
            'busiType': '5',
            'discntName': '通用流量',
            'balance': remaining,
            'highFee': total,
          },
          if (withDirected)
            {
              'busiType': '5',
              'discntName': '定向流量',
              'balance': '1',
              'highFee': '2',
            },
        ],
      },
    }, queriedAt: queriedAt),
  ];

  test('contradictory traffic rows stay unknown before and after caching', () {
    for (final snapshot in parseAll('3', '2', withDirected: true)) {
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.queriedAt, queriedAt);
      expect(snapshot.buckets, hasLength(2));
      expect(snapshot.buckets.first.rawRemaining, '3');
      expect(snapshot.buckets.first.rawUnit, 'KB');
      expect(snapshot.buckets.first.remainingBytes, isNull);
      expect(snapshot.buckets.first.totalBytes, isNull);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(summarizeTraffic(snapshot), isNull);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).state,
        'unavailable',
      );
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.directed).remainingBytes,
        1024,
      );
      final restored = CarrierSnapshot.fromJson(snapshot.toJson());
      expect(restored.toJson(), snapshot.toJson());
      expect(restored.generalRemainingBytes, isNull);
      expect(summarizeTraffic(restored), isNull);
    }
  });

  test('finite zero total and remaining remain provided across cache', () {
    for (final snapshot in parseAll('0', '0')) {
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.queriedAt, queriedAt);
      expect(snapshot.generalRemainingBytes, 0);
      expect(snapshot.generalTotalBytes, 0);
      expect(snapshot.buckets.single.isUnlimited, isFalse);
      expect(summarizeTraffic(snapshot)?.remainingBytes, 0);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).state,
        'provided',
      );
      expect(
        CarrierSnapshot.fromJson(snapshot.toJson()).toJson(),
        snapshot.toJson(),
      );
    }
  });

  test('missing or invalid total does not discard confirmed remaining', () {
    for (final total in [null, '-1', 'unknown']) {
      for (final snapshot in parseAll('3', total)) {
        expect(snapshot.status, QueryStatus.success);
        expect(snapshot.generalRemainingBytes, 3072);
        expect(snapshot.generalTotalBytes, isNull);
        expect(summarizeTraffic(snapshot)?.remainingBytes, 3072);
        expect(
          CarrierSnapshot.fromJson(snapshot.toJson()).toJson(),
          snapshot.toJson(),
        );
      }
    }
  });

  test('explicit unlimited rows never produce a finite cached amount', () {
    for (final snapshot in parseAll('不限量', '不限量')) {
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.buckets.single.isUnlimited, isTrue);
      expect(snapshot.buckets.single.remainingBytes, isNull);
      expect(snapshot.buckets.single.totalBytes, isNull);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).state,
        'unlimited',
      );
      expect(
        CarrierSnapshot.fromJson(snapshot.toJson()).toJson(),
        snapshot.toJson(),
      );
    }
  });

  test('failed cached rows retain original successful query time', () {
    for (final snapshot in parseAll('1', '2')) {
      for (final status in [QueryStatus.error, QueryStatus.authExpired]) {
        final failed = snapshot.copyWith(status: status);
        final restored = CarrierSnapshot.fromJson(failed.toJson());
        expect(restored.queriedAt, queriedAt);
        expect(restored.status, status);
        expect(restored.generalRemainingBytes, isNull);
        expect(summarizeTraffic(restored)?.remainingBytes, 1024);
      }
    }
  });
}
