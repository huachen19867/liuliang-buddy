import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  final queriedAt = DateTime.utc(2026, 9, 30, 3, 4, 5);

  test('mobile voice-only success explicitly reports absent traffic', () {
    final snapshot = parseMobile({
      'data': {
        'resultData': {
          'planRemianVoiceInfo': {
            'totalInfo': {'unit': '01', 'remainNum': '20', 'sumNum': '100'},
          },
        },
      },
    });
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, isEmpty);
    expect(snapshot.allowances.single.remaining, 20);
    expect(snapshot.message, contains('尚未返回可确认的流量额度'));
    expect(
      parseMobile({
        'data': {
          'resultData': {'planRemianFlowInfo': {}},
        },
      }).status,
      QueryStatus.error,
    );
  });

  test('mobile uses explicit units and keeps directed and total separate', () {
    final snapshot = parseMobile({
      'data': {
        'resultData': {
          'planRemianFlowInfo': {
            'planRemian': {'remainNum': '1.5', 'sumNum': '2', 'unit': '04'},
            'directionalFlowInfo': {
              'remainNum': '512',
              'sumNum': '1024',
              'unit': '03',
            },
            'otherRemian': {'remainNum': '9', 'sumNum': '10', 'unit': '04'},
            'totalInfo': {'remainNum': '11', 'sumNum': '13', 'unit': '04'},
          },
        },
      },
    }, queriedAt: queriedAt);

    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.queriedAt, queriedAt);
    expect(snapshot.generalRemainingBytes, 1610612736);
    expect(snapshot.generalTotalBytes, 2147483648);
    expect(snapshot.buckets.map((bucket) => bucket.kind), [
      BucketKind.general,
      BucketKind.directed,
      BucketKind.unknown,
      BucketKind.unknown,
    ]);
    expect(snapshot.buckets[1].remainingBytes, 536870912);
  });

  test('explicit zero remains distinct from missing balance', () {
    final zero = parseMobile({
      'data': {
        'resultData': {
          'planRemianFlowInfo': {
            'planRemian': {'remainNum': '0', 'unit': '03'},
          },
        },
      },
    });
    final missing = parseMobile({
      'data': {
        'resultData': {
          'planRemianFlowInfo': {
            'planRemian': {'unit': '03'},
          },
        },
      },
    });
    expect(zero.status, QueryStatus.success);
    expect(zero.generalRemainingBytes, 0);
    expect(missing.status, QueryStatus.error);
    expect(missing.generalRemainingBytes, isNull);
  });

  test('mobile rejects unknown or non-data units', () {
    for (final unit in ['01', 'mystery']) {
      final snapshot = parseMobile({
        'data': {
          'resultData': {
            'planRemianFlowInfo': {
              'planRemian': {'remainNum': '20', 'unit': unit},
            },
          },
        },
      });
      expect(snapshot.status, QueryStatus.error);
      expect(snapshot.generalRemainingBytes, isNull);
    }
  });

  test('broadnet preserves unlabelled units without inventing GB', () {
    final snapshot = parseBroadnet({
      'status': '000000',
      'data': {
        'intfResultBean': {
          'userResList': [
            {'itemName': '国内通用流量', 'balance': '1048576', 'highFee': '2097152'},
            {'itemName': '视频定向流量', 'balance': '1000'},
            {'itemName': '区域流量', 'balance': '2000'},
          ],
        },
      },
    }, queriedAt: queriedAt);

    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.generalRemainingBytes, isNull);
    expect(snapshot.buckets.map((bucket) => bucket.kind), [
      BucketKind.general,
      BucketKind.directed,
      BucketKind.unknown,
    ]);
    expect(snapshot.buckets.first.rawRemaining, '1048576');
    expect(snapshot.buckets.first.remainingBytes, isNull);
    expect(snapshot.message, contains('单位'));
  });

  test('broadnet converts an explicit unit and excludes directed traffic', () {
    final snapshot = parseBroadnet({
      'status': '000000',
      'data': {
        'intfResultBean': {
          'userResList': [
            {'itemName': '通用流量', 'balance': '1024', 'unit': 'KB'},
            {'itemName': '定向流量', 'balance': '5', 'unit': 'GB'},
            {'itemName': '通用语音', 'balance': '10', 'unit': 'GB'},
          ],
        },
      },
    });
    expect(snapshot.generalRemainingBytes, 1048576);
    expect(snapshot.generalTotalBytes, isNull);
    expect(snapshot.buckets[1].remainingBytes, 5368709120);
    expect(snapshot.buckets[2].kind, BucketKind.unknown);
  });

  test('broadnet H5 uses official KB fields and excludes voice and SMS', () {
    final snapshot = parseBroadnetH5({
      'respCode': '000000',
      'intfResultBean': {
        'userResList': [
          {
            'busiType': '5',
            'discntName': '国内通用流量',
            'balance': '1048576',
            'highFee': '2097152',
          },
          {
            'busiType': '5',
            'discntName': '视频定向流量',
            'balance': '512',
            'highFee': '1024',
          },
          {'busiType': '5', 'discntName': '30GB套餐', 'balance': '2048'},
          {'busiType': '1', 'discntName': '通用语音', 'balance': '200'},
          {'busiType': '2', 'discntName': '短信', 'balance': '100'},
        ],
      },
    }, queriedAt: queriedAt);
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.queriedAt, queriedAt);
    expect(snapshot.buckets, hasLength(3));
    expect(snapshot.generalRemainingBytes, 1073741824);
    expect(snapshot.generalTotalBytes, 2147483648);
    expect(snapshot.buckets[1].kind, BucketKind.directed);
    expect(snapshot.buckets[2].kind, BucketKind.unknown);
    expect(snapshot.buckets[2].remainingBytes, 2097152);
    expect(snapshot.buckets.first.rawUnit, 'KB');
  });

  test('broadnet H5 accepts wrapped official success only with inner gate', () {
    final wrapped = parseBroadnetH5({
      'status': '000000',
      'data': {
        'respCode': '000000',
        'intfResultBean': {
          'userResList': [
            {'busiType': '5', 'discntName': '流量包', 'balance': '0'},
          ],
        },
      },
    });
    expect(wrapped.status, QueryStatus.success);
    expect(wrapped.buckets.single.remainingBytes, 0);
    expect(wrapped.generalRemainingBytes, isNull);

    expect(
      parseBroadnetH5({
        'status': '000000',
        'data': {
          'intfResultBean': {'userResList': []},
        },
      }).status,
      QueryStatus.error,
    );
  });

  test('incomplete H5 flow rows block an incomplete detail sum', () {
    final snapshot = parseBroadnetH5({
      'respCode': '000000',
      'intfResultBean': {
        'userResList': [
          {'busiType': '5', 'discntName': '30GB升卿卡', 'balance': '31457280'},
          {'busiType': '5', 'discntName': '首充赠送'},
          {'busiType': '5', 'balance': '1048576'},
        ],
      },
    }, queriedAt: queriedAt);
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, hasLength(3));
    expect(snapshot.buckets.first.remainingBytes, 30 * 1024 * 1024 * 1024);
    expect(snapshot.buckets[1].remainingBytes, isNull);
    expect(snapshot.buckets[2].name, '未命名流量套餐');
    expect(snapshot.buckets[2].remainingBytes, isNull);
    expect(snapshot.message, contains('暂不显示明细合计'));
    expect(summarizeTraffic(snapshot), isNull);
  });

  test('broadnet H5 rejects expired and unconfirmed responses', () {
    expect(
      parseBroadnetH5({
        'status': '701',
        'message': '登录已过期，请重新登录',
        'data': null,
        'ok': false,
      }).status,
      QueryStatus.authExpired,
    );
    expect(
      parseBroadnetH5({}, httpStatus: 401).status,
      QueryStatus.authExpired,
    );
    expect(parseBroadnetH5({}).status, QueryStatus.error);
    expect(parseBroadnetH5({'respCode': '999999'}).status, QueryStatus.error);
    final voiceOnly = parseBroadnetH5({
      'respCode': '000000',
      'intfResultBean': {
        'userResList': [
          {'busiType': '1', 'discntName': '语音', 'balance': '200'},
        ],
      },
    });
    expect(voiceOnly.status, QueryStatus.success);
    expect(voiceOnly.buckets, isEmpty);
    expect(voiceOnly.allowances.single.remaining, 200);
  });

  test('authentication and malformed bodies never become success', () {
    expect(parseMobile({}, httpStatus: 401).status, QueryStatus.authExpired);
    expect(parseBroadnet({}, httpStatus: 403).status, QueryStatus.authExpired);
    expect(
      parseBroadnet({'status': '123', 'message': '登录已失效'}).status,
      QueryStatus.authExpired,
    );
    expect(parseMobile({}).status, QueryStatus.error);
    expect(parseBroadnet({'status': '000000'}).status, QueryStatus.error);
  });

  test('snapshot JSON preserves query time and nullable totals', () {
    final original = CarrierSnapshot(
      carrier: Carrier.broadnet,
      status: QueryStatus.success,
      queriedAt: queriedAt,
      buckets: const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 0,
          rawRemaining: '0',
        ),
      ],
    );
    final restored = CarrierSnapshot.fromJson(original.toJson());
    expect(restored.queriedAt, queriedAt);
    expect(restored.generalRemainingBytes, 0);
    expect(restored.generalTotalBytes, isNull);
    expect(restored.copyWith(queriedAt: null).queriedAt, isNull);
  });
}
