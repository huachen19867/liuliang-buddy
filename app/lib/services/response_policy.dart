import '../data/models.dart';

/// An official decoded response is preferred. A raw response can be used only
/// when the carrier parser has already verified a plaintext business success.
/// Once a success is on screen, a later raw event from the same page is ignored.
bool shouldApplyBroadnetResponse({
  required String? stage,
  required QueryStatus parsedStatus,
  required QueryStatus currentStatus,
  int? httpStatus,
}) {
  if (stage == 'officialDecoded') return true;
  if (stage != 'raw' || currentStatus == QueryStatus.success) return false;
  if (parsedStatus == QueryStatus.success ||
      parsedStatus == QueryStatus.authExpired) {
    return true;
  }
  return httpStatus != null && (httpStatus < 200 || httpStatus >= 300);
}
