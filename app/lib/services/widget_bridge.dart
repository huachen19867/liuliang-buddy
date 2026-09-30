import 'package:flutter/services.dart';

import '../data/models.dart';

/// Display-only snapshot. No phone numbers, credentials or raw responses.
Map<String, Object?> buildWidgetPayload(
  Iterable<CarrierSnapshot> snapshots, {
  required double thresholdGb,
}) {
  final payload = <String, Object?>{'schema': 1, 'thresholdGb': thresholdGb};
  for (final carrier in Carrier.values) {
    final snapshot = snapshots
        .where((item) => item.carrier == carrier)
        .firstOrNull;
    int? remaining;
    var label = '通用剩余';
    if (snapshot?.queriedAt != null) {
      remaining = snapshot!
          .copyWith(status: QueryStatus.success)
          .generalRemainingBytes;
      // A single unclassified package may be shown with its actual limitation;
      // multiple unknown packages are never added together.
      if (remaining == null && snapshot.buckets.length == 1) {
        final bucket = snapshot.buckets.single;
        if (bucket.kind == BucketKind.unknown) {
          remaining = bucket.remainingBytes;
          label = '套餐余量·用途待确认';
        }
      }
    }
    payload[carrier.name] = <String, Object?>{
      'status': snapshot?.status.name ?? QueryStatus.notConnected.name,
      'remainingBytes': remaining,
      'label': label,
      'queriedAt': snapshot?.queriedAt?.millisecondsSinceEpoch,
    };
  }
  return payload;
}

class WidgetBridge {
  const WidgetBridge();
  static const channel = MethodChannel('cn.liuliang/widgets');

  void onOpen(Future<void> Function()? handler) => channel.setMethodCallHandler(
    handler == null
        ? null
        : (call) async {
            if (call.method == 'openFromWidget') await handler();
          },
  );

  Future<void> update(
    Iterable<CarrierSnapshot> snapshots,
    double thresholdGb,
  ) async {
    try {
      await channel.invokeMethod<void>(
        'updateSnapshot',
        buildWidgetPayload(snapshots, thresholdGb: thresholdGb),
      );
    } on PlatformException {
      /* A launcher failure cannot replace carrier data. */
    }
  }

  Future<void> clear() => channel.invokeMethod<void>('clearSnapshot');

  Future<bool> consumeLaunchRefresh() async =>
      await channel.invokeMethod<bool>('consumeLaunchRefresh') ?? false;

  Future<bool> requestPin() async {
    final result = await channel.invokeMapMethod<String, Object?>('requestPin');
    return result?['requested'] == true;
  }
}
