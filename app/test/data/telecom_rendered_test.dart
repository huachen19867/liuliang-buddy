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
