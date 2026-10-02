import 'dart:async';

import '../data/models.dart';

/// Joins only this WebView query's results, never a cached account balance.
class MobileQueryAssembly {
  final Completer<num?> _balance = Completer<num?>();
  bool _flowClaimed = false;
  bool _cancelled = false;

  bool claimFlow() {
    if (_flowClaimed || _cancelled) return false;
    _flowClaimed = true;
    return true;
  }

  void acceptBalance(num? amount) {
    if (_cancelled || amount == null || _balance.isCompleted) return;
    _balance.complete(amount);
  }

  void cancel() {
    _cancelled = true;
    if (!_balance.isCompleted) _balance.complete(null);
  }

  Future<CarrierSnapshot> assemble(
    CarrierSnapshot flow, {
    Duration wait = const Duration(seconds: 5),
  }) async {
    if (flow.status != QueryStatus.success) return flow;
    final amount = await _balance.future.timeout(wait, onTimeout: () => null);
    return flow.copyWith(
      balanceYuan: _cancelled ? null : amount,
      message: amount == null || _cancelled
          ? '${flow.message ?? '流量已更新'}；话费余额暂未取得'
          : flow.message,
    );
  }
}
