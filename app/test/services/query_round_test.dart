import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/query_round.dart';

void main() {
  test('each account has its own current attempt', () {
    final rounds = QueryRoundRegistry();
    final mobile = rounds.begin('mobile');
    final otherMobile = rounds.begin('mobile_2');
    expect(rounds.current('mobile'), mobile);
    expect(rounds.current('mobile_2'), otherMobile);
    expect(rounds.isCurrent('mobile', otherMobile), isFalse);
    expect(rounds.isCurrent('missing', null), isFalse);
    expect(rounds.isCurrent('missing', mobile), isFalse);
    expect(rounds.finish('mobile_2', otherMobile), isTrue);
    expect(rounds.current('mobile_2'), isNull);
    expect(rounds.isCurrent('mobile', mobile), isTrue);
  });

  test('late finish and cancellation do not revive or clear a newer attempt', () {
    final rounds = QueryRoundRegistry();
    final old = rounds.begin('mobile');
    final current = rounds.begin('mobile');
    expect(current, isNot(old));
    expect(rounds.isCurrent('mobile', old), isFalse);
    expect(rounds.finish('mobile', old), isFalse);
    expect(rounds.isCurrent('mobile', current), isTrue);
    rounds.cancel('mobile');
    expect(rounds.current('mobile'), isNull);
    expect(rounds.finish('mobile', current), isFalse);
    expect(rounds.begin('mobile'), isNot(isIn([old, current])));
  });

  test('clear invalidates all tokens without resetting their identity', () {
    final rounds = QueryRoundRegistry();
    final before = [rounds.begin('mobile'), rounds.begin('telecom')];
    rounds.clear();
    expect(rounds.current('mobile'), isNull);
    expect(rounds.current('telecom'), isNull);
    expect(rounds.begin('mobile'), isNot(isIn(before)));
    expect(rounds.begin('telecom'), isNot(isIn(before)));
  });

  test('query identity stays short and contains no account data', () {
    final rounds = QueryRoundRegistry();
    const account = 'private-phone-13800000000';
    final tokens = List.generate(100, (_) => rounds.begin(account));
    expect(tokens.toSet(), hasLength(100));
    for (final token in tokens) {
      expect(token.length, lessThanOrEqualTo(32));
      expect(token, matches(r'^q[a-z0-9]+_[a-z0-9]+$'));
      expect(token, isNot(contains(account)));
      expect(token, isNot(contains('13800000000')));
    }
  });
}
