import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/refresh_throttle.dart';

void main() {
  test('official login return can query again inside the 30-second window', () {
    final throttle = RefreshThrottle();
    final now = DateTime(2026, 10, 1, 12);
    throttle.started('unicom', now);
    expect(
      throttle.blocks('unicom', now.add(const Duration(seconds: 5))),
      isTrue,
    );
    throttle.loginOrLoadFailed('unicom');
    expect(
      throttle.blocks('unicom', now.add(const Duration(seconds: 5))),
      isFalse,
    );
    throttle.started('unicom', now.add(const Duration(seconds: 5)));
    expect(
      throttle.blocks('unicom', now.add(const Duration(seconds: 35))),
      isFalse,
    );
  });

  test('another account keeps its own request cooldown', () {
    final throttle = RefreshThrottle();
    final now = DateTime(2026, 10, 1, 12);
    throttle.started('mobile', now);
    throttle.started('mobile_2', now);
    throttle.loginOrLoadFailed('mobile_2');
    expect(
      throttle.blocks('mobile', now.add(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      throttle.blocks('mobile_2', now.add(const Duration(seconds: 1))),
      isFalse,
    );
  });
}
