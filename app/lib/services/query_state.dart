import '../data/models.dart';

/// A cancelled WebView request has no live timer or response handler left.
/// Keep its previous balance and query time as stale context for retry.
CarrierSnapshot settleInterruptedQuery(CarrierSnapshot snapshot) =>
    snapshot.status == QueryStatus.loading
    ? snapshot.copyWith(status: QueryStatus.error, message: '本次查询已中断，请重新刷新')
    : snapshot;
