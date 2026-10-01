import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';

void main() {
  test('old cache remains readable and copyWith preserves new allowances', () {
    final old = CarrierSnapshot.fromJson({
      'carrier': 'unicom',
      'status': 'success',
      'queriedAt': '2026-10-01T12:00:00.000Z',
      'buckets': [],
    });
    expect(old.allowances, isEmpty);
    final withVoice = old.copyWith(
      allowances: const [
        ServiceAllowance(
          kind: AllowanceKind.voice,
          label: '语音',
          remaining: 0,
          rawUnit: '分钟',
        ),
      ],
    );
    final restored = CarrierSnapshot.fromJson(withVoice.toJson());
    expect(restored.allowances.single.remaining, 0);
    expect(restored.allowances.single.canonicalUnit, '分钟');
    expect(
      restored.copyWith(status: QueryStatus.error).allowances,
      hasLength(1),
    );
    expect(restored.queriedAt, old.queriedAt);
  });

  test('malformed cached amount is skipped without losing traffic data', () {
    final restored = CarrierSnapshot.fromJson({
      'carrier': 'unicom',
      'status': 'success',
      'buckets': [
        {'name': '官网套餐余量', 'kind': 'unknown', 'remainingBytes': 0},
      ],
      'allowances': [
        {'kind': 'sms', 'label': '短、彩信', 'remaining': 1.5},
        {'kind': 'voice', 'label': '语音', 'remaining': -1},
        {'kind': 'sms', 'label': '短、彩信', 'remaining': 0},
      ],
    });
    expect(restored.buckets.single.remainingBytes, 0);
    expect(restored.allowances, hasLength(1));
    expect(restored.allowances.single.remaining, 0);
  });

  test('Unicom E5 preserves voice minutes and short/MMS combined count', () {
    final snapshot = parseUnicomWeb({
      'resource': {
        'flowFlag': false,
        'voiceFlag': true,
        'remainVoice': '12.5',
        'overVoice': 0,
        'smsFlag': true,
        'remainSms': '0',
        'overSms': 0,
      },
    });
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, isEmpty);
    expect(snapshot.allowances, hasLength(2));
    expect(snapshot.allowances[0].remaining, 12.5);
    expect(snapshot.allowances[1].label, '短、彩信');
    expect(snapshot.allowances[1].remaining, 0);
    expect(snapshot.allowances[1].canonicalUnit, '条');
  });

  test('Unicom overage never reuses stale remaining values', () {
    final snapshot = parseUnicomWeb({
      'resource': {
        'flowFlag': false,
        'voiceFlag': true,
        'remainVoice': 99,
        'overVoice': 3,
      },
    });
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.allowances.single.remaining, isNull);
    expect(snapshot.allowances.single.overage, 3);
  });

  test('flags and untrusted units never turn missing records into zero', () {
    for (final resource in [
      {'successFlow': false, 'voiceFlag': true, 'remainVoice': 10},
      {'flowFlag': false, 'voiceFlag': false, 'remainVoice': 0},
      {'flowFlag': false, 'smsFlag': true, 'remainSms': '1.5'},
      {'flowFlag': false, 'voiceFlag': true, 'remainVoice': '-1'},
    ]) {
      final snapshot = parseUnicomWeb({'resource': resource});
      expect(snapshot.status, QueryStatus.error);
      expect(snapshot.allowances, isEmpty);
    }
  });

  test(
    'mobile voice-only response retains total summary without summing rows',
    () {
      final snapshot = parseMobile({
        'data': {
          'resultData': {
            'planRemianVoiceInfo': {
              'planRemian': {'remainNum': '10', 'sumNum': '20', 'unit': '01'},
              'otherRemian': {'remainNum': '5', 'unit': '01'},
              'totalInfo': {'remainNum': '12', 'sumNum': '25', 'unit': '01'},
            },
            'planRemianMSGInfo': {
              'notePlanRemian': {
                'remainNum': '0',
                'sumNum': '100',
                'unit': '02',
              },
              'totalInfo': {'remainNum': '3', 'unit': '02'},
            },
          },
        },
      });
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.buckets, isEmpty);
      expect(snapshot.allowances, hasLength(2));
      expect(snapshot.allowances[0].remaining, 12);
      expect(snapshot.allowances[0].scope, '官网汇总');
      expect(snapshot.allowances[1].remaining, 3);
    },
  );

  test(
    'mobile falls back to separate package rows without a valid summary',
    () {
      final snapshot = parseMobile({
        'data': {
          'resultData': {
            'planRemianVoiceInfo': {
              'planRemian': {'remainNum': '10', 'unit': '01'},
              'otherRemian': {'remainNum': '5', 'unit': '01'},
              'totalInfo': {'remainNum': null, 'unit': '01'},
            },
          },
        },
      });
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.allowances, hasLength(2));
      expect(snapshot.allowances.map((row) => row.remaining), [10, 5]);
      expect(snapshot.allowances.every((row) => row.scope == '套餐明细'), isTrue);
    },
  );

  test('mobile rejects unknown units, missing amounts and auth failures', () {
    final snapshot = parseMobile({
      'data': {
        'resultData': {
          'planRemianVoiceInfo': {
            'planRemian': {'remainNum': '20', 'unit': '02'},
            'totalInfo': {'remainNum': '-1', 'unit': '01'},
          },
          'planRemianMSGInfo': {
            'notePlanRemian': {'remainNum': '1.5', 'unit': '02'},
            'totalInfo': {'sumNum': '100', 'unit': '02'},
          },
        },
      },
    });
    expect(snapshot.status, QueryStatus.error);
    expect(snapshot.allowances, isEmpty);
    expect(
      parseMobile({
        'message': '登录已失效',
        'data': {
          'resultData': {
            'planRemianVoiceInfo': {
              'totalInfo': {'remainNum': '20', 'unit': '01'},
            },
          },
        },
      }).status,
      QueryStatus.authExpired,
    );
  });

  test('broadnet H5 voice-only and explicit short-message rows', () {
    final snapshot = parseBroadnetH5({
      'respCode': '000000',
      'intfResultBean': {
        'userResList': [
          {
            'busiType': '1',
            'discntName': '国内语音',
            'balance': '0',
            'highFee': '100',
          },
          {
            'busiType': '2',
            'discntName': '短彩信',
            'balance': '5',
            'highFee': '10',
          },
          {'busiType': '2', 'discntName': '积分权益', 'balance': '30'},
          {'busiType': '3', 'discntName': '彩信', 'balance': '3'},
        ],
      },
    });
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, isEmpty);
    expect(snapshot.allowances, hasLength(2));
    expect(snapshot.allowances.first.remaining, 0);
    expect(snapshot.allowances.last.remaining, 5);
    expect(snapshot.allowances.last.canonicalUnit, '条');
  });

  test('broadnet H5 business failure and unknown type cannot become SMS', () {
    final invalid = {
      'intfResultBean': {
        'userResList': [
          {'busiType': '2', 'discntName': '积分权益', 'balance': '30'},
        ],
      },
    };
    expect(
      parseBroadnetH5({'respCode': '999999', ...invalid}).status,
      QueryStatus.error,
    );
    expect(
      parseBroadnetH5({'respCode': '000000', ...invalid}).status,
      QueryStatus.error,
    );
    expect(
      parseBroadnetH5({
        'respCode': '000000',
        'intfResultBean': {
          'userResList': [
            {'busiType': '1', 'discntName': '语音', 'balance': '-1'},
          ],
        },
      }).status,
      QueryStatus.error,
    );
  });

  test('telecom voice-only estimate and SMS 次 remain separate', () {
    final voice = parseTelecomRendered({
      'source': 'officialRendered',
      'rows': [],
      'allowanceRows': [
        {'kind': 'voice', 'name': '国内通话', 'used': '3分钟', 'total': '20分钟'},
      ],
    });
    expect(voice.status, QueryStatus.success);
    expect(voice.buckets, isEmpty);
    expect(voice.allowances.single.remaining, 17);
    expect(voice.allowances.single.isEstimated, isTrue);

    final sms = parseTelecomRendered({
      'source': 'officialRendered',
      'rows': [],
      'allowanceRows': [
        {'kind': 'sms', 'name': '国内短信', 'used': '1次', 'total': '20次'},
        {'kind': 'sms', 'name': '权益次数', 'used': '1次', 'total': '20次'},
      ],
    });
    expect(sms.status, QueryStatus.success);
    expect(sms.allowances, hasLength(1));
    expect(sms.allowances.single.remaining, 19);
    expect(sms.allowances.single.canonicalUnit, '次');
    expect(sms.allowances.single.isEstimated, isTrue);
    expect(
      CarrierSnapshot.fromJson(sms.toJson()).allowances.single.canonicalUnit,
      '次',
    );
  });

  test('telecom rejects incompatible units and preserves overage', () {
    final mismatch = parseTelecomRendered({
      'source': 'officialRendered',
      'rows': [],
      'allowanceRows': [
        {'kind': 'sms', 'name': '短信', 'used': '1次', 'total': '20条'},
      ],
    });
    expect(mismatch.status, QueryStatus.error);
    final exceeded = parseTelecomRendered({
      'source': 'officialRendered',
      'rows': [],
      'allowanceRows': [
        {'kind': 'voice', 'name': '语音', 'used': '21分钟', 'total': '20分钟'},
      ],
    });
    expect(exceeded.status, QueryStatus.success);
    expect(exceeded.allowances.single.remaining, isNull);
    expect(exceeded.allowances.single.overage, 1);
  });
}
