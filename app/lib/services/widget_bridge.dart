import 'package:flutter/services.dart';

import '../data/carrier_accounts.dart';
import '../data/models.dart';
import '../data/carrier_selection.dart';
import '../data/traffic_summary.dart';

/// Display-only snapshot. Only masked phone hints, no credentials or raw data.
Map<String, Object?> buildWidgetPayload(
  Iterable<CarrierSnapshot> snapshots, {
  required double thresholdGb,
  CarrierSelection? selection,
  CarrierAccounts? accounts,
  Map<String, CarrierSnapshot> accountSnapshots = const {},
}) {
  final selected = selection?.selectedCarriers ?? Carrier.values.toSet();
  final byCarrier = <Carrier, CarrierSnapshot>{};
  for (final snapshot in snapshots) {
    if (selected.contains(snapshot.carrier)) {
      byCarrier.putIfAbsent(snapshot.carrier, () => snapshot);
    }
  }
  final payload = <String, Object?>{
    'schema': accounts == null ? 1 : 2,
    'thresholdGb': thresholdGb,
    'selectedCarriers': [
      for (final carrier in Carrier.values)
        if (selected.contains(carrier)) carrier.name,
    ],
  };
  for (final carrier in Carrier.values) {
    final candidate = !selected.contains(carrier)
        ? null
        : (accounts == null
              ? byCarrier[carrier]
              : accountSnapshots[carrier.name]);
    final snapshot = candidate?.carrier == carrier ? candidate : null;
    final summary = snapshot == null ? null : summarizeTraffic(snapshot);
    final unlimited =
        snapshot != null &&
        snapshot.queriedAt != null &&
        summary == null &&
        snapshot.hasUnlimitedAllowance;
    payload[carrier.name] = <String, Object?>{
      'status': snapshot?.status.name ?? QueryStatus.notConnected.name,
      'remainingBytes': summary?.remainingBytes,
      'label': summary?.label ?? '余额待确认',
      'queriedAt': snapshot?.queriedAt?.millisecondsSinceEpoch,
      'unlimited': unlimited,
    };
  }
  if (accounts != null) {
    final instances = <Map<String, Object?>>[];
    for (final account in accounts.accounts) {
      if (!selected.contains(account.carrier) || instances.length >= 4) {
        continue;
      }
      // An account map is authoritative. The carrier list may contain only a
      // secondary result; falling back to it would copy that balance to primary.
      final candidate = accountSnapshots[account.id];
      final snapshot = candidate?.carrier == account.carrier ? candidate : null;
      final summary = snapshot == null ? null : summarizeTraffic(snapshot);
      final unlimited =
          snapshot != null &&
          snapshot.queriedAt != null &&
          summary == null &&
          snapshot.hasUnlimitedAllowance;
      final general = snapshot == null
          ? const TrafficGroupSummary()
          : summarizeTrafficGroup(snapshot, BucketKind.general);
      final directed = snapshot == null
          ? const TrafficGroupSummary()
          : summarizeTrafficGroup(snapshot, BucketKind.directed);
      final other = snapshot == null
          ? const TrafficGroupSummary()
          : summarizeTrafficGroup(snapshot, BucketKind.unknown);
      final voice = snapshot == null ? null : summarizeVoice(snapshot);
      instances.add({
        'accountId': account.id,
        'carrier': account.carrier.name,
        'accountLabel': account.label,
        'name': account.displayName,
        'phoneHint': account.phoneHint,
        'balanceYuan': snapshot?.queriedAt == null
            ? null
            : snapshot?.balanceYuan,
        'generalRemainingBytes': general.remainingBytes,
        'generalState': general.state,
        'directedRemainingBytes': directed.remainingBytes,
        'directedState': directed.state,
        'otherRemainingBytes': other.remainingBytes,
        'otherState': other.state,
        'trafficEstimated':
            general.isEstimated || directed.isEstimated || other.isEstimated,
        'voiceRemainingMinutes': voice?.remaining,
        'voiceState': voice?.isUnlimited == true
            ? 'unlimited'
            : voice?.remaining != null
            ? 'provided'
            : 'unavailable',
        'voiceEstimated': voice?.isEstimated ?? false,
        'status': snapshot?.status.name ?? QueryStatus.notConnected.name,
        'primaryValue': summary?.remainingBytes,
        'primaryLabel': unlimited ? '含不限量套餐' : summary?.label ?? '余额待确认',
        'queriedAt': snapshot?.queriedAt?.millisecondsSinceEpoch,
        'isUnlimited': unlimited,
      });
    }
    payload['instances'] = instances;
  }
  return payload;
}

enum WidgetPinStatus {
  alreadyAdded('already_added'),
  requestPendingConfirmation('request_pending_confirmation'),
  unsupported('unsupported'),
  notAdded('not_added');

  const WidgetPinStatus(this.wireValue);
  final String wireValue;

  static WidgetPinStatus parse(Object? value) =>
      WidgetPinStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => WidgetPinStatus.unsupported,
      );
}

class WidgetPinResult {
  const WidgetPinResult(this.status, {this.reason});

  final WidgetPinStatus status;
  final String? reason;

  bool get isAlreadyAdded => status == WidgetPinStatus.alreadyAdded;
  bool get isPendingConfirmation =>
      status == WidgetPinStatus.requestPendingConfirmation;
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
    double thresholdGb, {
    CarrierSelection? selection,
    CarrierAccounts? accounts,
    Map<String, CarrierSnapshot> accountSnapshots = const {},
  }) async {
    try {
      await channel.invokeMethod<void>(
        'updateSnapshot',
        buildWidgetPayload(
          snapshots,
          thresholdGb: thresholdGb,
          selection: selection,
          accounts: accounts,
          accountSnapshots: accountSnapshots,
        ),
      );
    } on PlatformException {
      /* A launcher failure cannot replace carrier data. */
    }
  }

  Future<void> clear() => channel.invokeMethod<void>('clearSnapshot');

  Future<bool> consumeLaunchRefresh() async =>
      await channel.invokeMethod<bool>('consumeLaunchRefresh') ?? false;

  Future<WidgetPinResult> installationStatus() async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'installationStatus',
    );
    return WidgetPinResult(
      WidgetPinStatus.parse(result?['status']),
      reason: result?['reason'] as String?,
    );
  }

  Future<WidgetPinResult> requestPinDetailed() async {
    final result = await channel.invokeMapMethod<String, Object?>('requestPin');
    return WidgetPinResult(
      WidgetPinStatus.parse(result?['status']),
      reason: result?['reason'] as String?,
    );
  }

  /// Legacy convenience API: true means the Launcher accepted a request.
  /// It does not assert that the user has added the widget.
  Future<bool> requestPin() async {
    final result = await requestPinDetailed();
    return result.isPendingConfirmation;
  }
}
