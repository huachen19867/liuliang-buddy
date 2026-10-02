import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/parsers.dart';
import 'package:liuliang_app/data/traffic_summary.dart';
import 'package:liuliang_app/services/widget_bridge.dart';
import 'package:liuliang_app/data/carrier_selection.dart';

void main() {
  Map<String, dynamic> row(String used, String total, {String name = '国内流量'}) =>
      {'name': name, 'used': used, 'total': total};
  Map<String, dynamic> sample(List<Object?> rows) => {
    'source': 'officialRendered',
    'rows': rows,
  };
  test('only the literal directed name marker classifies Telecom rows', () {
    final names = [
      '国内上网流量',
      '国内上网含5GB',
      '国内上网含100G',
      '国内通用流量',
      '视频专属流量',
      '国内上网含5GB定向流量',
      '定向通用流量',
      ' 定向流量 ',
    ];
    final snapshot = parseTelecomRendered(
      sample([for (final name in names) row('1GB', '5GB', name: name)]),
    );
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, hasLength(names.length));
    expect(snapshot.buckets.map((bucket) => bucket.kind), [
      ...List.filled(5, BucketKind.unknown),
      ...List.filled(3, BucketKind.directed),
    ]);
    expect(snapshot.generalRemainingBytes, isNull);
    expect(snapshot.buckets.last.name, '定向流量');
    expect(
      snapshot.buckets.every((bucket) => bucket.manualKind == null),
      isTrue,
    );
  });
  test('name amounts never supply or override the rendered traffic amount', () {
    final snapshot = parseTelecomRendered(
      sample([
        row('512MB', '2GB', name: '国内上网含100G'),
        row('--MB', '5GB', name: '国内上网含5GB定向流量'),
      ]),
    );
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets.first.kind, BucketKind.unknown);
    expect(snapshot.buckets.first.remainingBytes, 1536 * 1024 * 1024);
    expect(snapshot.buckets.last.kind, BucketKind.directed);
    expect(snapshot.buckets.last.remainingBytes, isNull);
    expect(snapshot.buckets.last.totalBytes, isNull);
    expect(summarizeTraffic(snapshot), isNull);
  });
  test('same-name rows remain separate with their individual amounts', () {
    final snapshot = parseTelecomRendered(
      sample([
        row('1GB', '5GB', name: '定向流量'),
        row('2GB', '5GB', name: '定向流量'),
        row('1GB', '5GB', name: '国内上网流量'),
        row('2GB', '5GB', name: '国内上网流量'),
      ]),
    );
    expect(snapshot.buckets, hasLength(4));
    expect(snapshot.buckets.map((bucket) => bucket.kind), [
      BucketKind.directed,
      BucketKind.directed,
      BucketKind.unknown,
      BucketKind.unknown,
    ]);
    expect(snapshot.buckets.map((bucket) => bucket.remainingBytes), [
      4 * 1024 * 1024 * 1024,
      3 * 1024 * 1024 * 1024,
      4 * 1024 * 1024 * 1024,
      3 * 1024 * 1024 * 1024,
    ]);
  });
  test('currency requires rendered yuan and cannot reuse traffic balance', () {
    final response = sample([row('0MB', '1GB')]);
    expect(
      parseTelecomRendered({...response, 'balanceText': '12.34 元'}).balanceYuan,
      12.34,
    );
    expect(
      parseTelecomRendered({...response, 'balanceText': '-3.20 元'}).balanceYuan,
      -3.2,
    );
    expect(
      parseTelecomRendered({...response, 'balanceText': '0 元'}).balanceYuan,
      0,
    );
    for (final text in [
      '12.34',
      '12.34 KB',
      'NaN 元',
      '1.234 元',
      '-- 元',
      '余额 12.34 元',
      '1e3 元',
    ]) {
      expect(
        parseTelecomRendered({...response, 'balanceText': text}).balanceYuan,
        isNull,
      );
    }
    expect(
      parseTelecomRendered({...response, 'balance': 12345}).balanceYuan,
      isNull,
    );
  });
  test(
    'independent MB/GB units are subtracted and always tagged as estimated package balances',
    () {
      final snapshot = parseTelecomRendered(
        sample([row('512.00MB', '2.00GB')]),
      );
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.buckets.single.remainingBytes, 1536 * 1024 * 1024);
      expect(snapshot.generalRemainingBytes, isNull);
      final summary = summarizeTraffic(snapshot)!;
      expect(summary.isEstimate, isTrue);
      expect(summary.label, '套餐估算余量');
      expect(summary.detailNotice, contains('舍入'));
      final payload = buildWidgetPayload(
        [snapshot],
        thresholdGb: 5,
        selection: CarrierSelection.complete([Carrier.telecom]),
      );
      expect((payload['telecom'] as Map)['label'], '套餐估算余量');
    },
  );
  test(
    'one incomplete row blocks aggregate while preserving the identified rows',
    () {
      final snapshot = parseTelecomRendered(
        sample([row('0MB', '1GB'), row('--MB', '10GB')]),
      );
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.buckets, hasLength(2));
      expect(snapshot.buckets.first.remainingBytes, 1024 * 1024 * 1024);
      expect(snapshot.buckets.last.remainingBytes, isNull);
      expect(summarizeTraffic(snapshot), isNull);
    },
  );
  test(
    'used, totals, unlimited sentinels, blank names and unknown units cannot become zero',
    () {
      for (final item in [
        row('20MB', '10MB'),
        row('0MB', '0MB'),
        row('1MB', '99999999999GB'),
        row('0MB', '1GB', name: ''),
        row('1分钟', '10分钟'),
        row('NaNMB', '1GB'),
      ]) {
        expect(
          parseTelecomRendered(sample([item])).status,
          QueryStatus.error,
          reason: '$item',
        );
      }
      expect(
        parseTelecomRendered(
          sample([row('1GB', '1GB')]),
        ).buckets.single.remainingBytes,
        0,
      );
    },
  );
  test(
    'no source, no rows and truncated lists cannot be billed as an authenticated result',
    () {
      expect(
        parseTelecomRendered({
          'rows': [row('0GB', '1GB')],
        }).status,
        QueryStatus.error,
      );
      expect(parseTelecomRendered(sample([])).status, QueryStatus.error);
      expect(parseTelecomRendered(sample([null])).status, QueryStatus.error);
      expect(
        parseTelecomRendered(
          sample(List.filled(201, row('0GB', '1GB'))),
        ).status,
        QueryStatus.error,
      );
    },
  );
}
