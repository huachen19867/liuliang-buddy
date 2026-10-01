import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  final time = DateTime.utc(2026, 10, 1);
  Map<String, dynamic> mobile(Object? remaining, {String? unit}) => {
    'data': {
      'resultData': {
        'planRemianFlowInfo': {
          'planRemian': {'remainNum': remaining, 'unit': ?unit},
        },
      },
    },
  };

  test(
    'all four carriers finish explicit unlimited results without inventing bytes',
    () {
      final snapshots = [
        parseMobile(mobile('不限量'), queriedAt: time),
        parseUnicomWeb({
          'resource': {
            'successFlow': true,
            'hasNolimitedFlow': true,
            'usedFlow': 123,
          },
        }, queriedAt: time),
        parseBroadnetH5({
          'respCode': '000000',
          'intfResultBean': {
            'userResList': [
              {'busiType': '5', 'discntName': '国内流量', 'balance': '不限量'},
            ],
          },
        }, queriedAt: time),
        parseTelecomRendered({
          'source': 'officialRendered',
          'rows': [
            {'name': '国内流量', 'used': '500MB', 'total': '不限量'},
          ],
        }, queriedAt: time),
      ];
      for (final snapshot in snapshots) {
        expect(
          snapshot.status,
          QueryStatus.success,
          reason: snapshot.carrier.name,
        );
        expect(snapshot.queriedAt, time);
        expect(snapshot.hasUnlimitedAllowance, isTrue);
        expect(snapshot.generalRemainingBytes, isNull);
        expect(snapshot.generalTotalBytes, isNull);
        expect(
          snapshot.buckets.every(
            (b) => b.remainingBytes == null && b.totalBytes == null,
          ),
          isTrue,
        );
        expect(summarizeTraffic(snapshot), isNull);
        final restored = CarrierSnapshot.fromJson(snapshot.toJson());
        expect(restored.hasUnlimitedAllowance, isTrue);
        expect(restored.queriedAt, time);
      }
    },
  );

  test(
    'finite high-speed quota, sentinel and voice units are not unlimited data',
    () {
      final finite = parseMobile(mobile('100', unit: '03'));
      expect(finite.hasUnlimitedAllowance, isFalse);
      expect(finite.generalRemainingBytes, 100 * 1024 * 1024);
      for (final invalid in [
        '-1',
        'Infinity',
        '99999999999999999999999999999999999999',
        '--',
        '不限量优惠',
      ]) {
        final result = parseMobile(mobile(invalid, unit: '04'));
        expect(result.status, QueryStatus.error, reason: invalid);
        expect(result.hasUnlimitedAllowance, isFalse);
        expect(result.generalRemainingBytes, isNull);
      }
      expect(parseMobile(mobile('不限量', unit: '01')).status, QueryStatus.error);
      expect(
        parseMobile(mobile('不限量'), httpStatus: 401).status,
        QueryStatus.authExpired,
      );
    },
  );

  test(
    'legacy cached buckets remain finite; explicit unlimited cannot enter sums',
    () {
      final old = TrafficBucket.fromJson({
        'name': '通用流量',
        'kind': 'general',
        'remainingBytes': 1,
      });
      expect(old.isUnlimited, isFalse);
      final snapshot = CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: const [
          TrafficBucket(
            name: '国内流量',
            kind: BucketKind.general,
            isUnlimited: true,
            remainingBytes: 123,
          ),
        ],
      );
      expect(snapshot.generalRemainingBytes, isNull);
      expect(summarizeTraffic(snapshot), isNull);
    },
  );
}
