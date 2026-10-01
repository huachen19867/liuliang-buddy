import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';

void main() {
  final selection = CarrierSelection.complete([Carrier.mobile]);
  test('identity edits survive storage without changing session keys', () {
    final original = CarrierAccounts.fromSelection(
      selection,
    ).addSecond(Carrier.mobile);
    final updated = original.updateIdentity(
      'mobile_2',
      note: ' 上网卡 ',
      phoneNumber: '13812345678',
    );
    final restored = CarrierAccounts.restore(
      savedJson: updated.toStorageString(),
      selection: selection,
    );
    final second = restored.find('mobile_2')!;
    expect(second.displayName, '上网卡');
    expect(second.phoneHint, '138****5678');
    expect(second.phoneNumber, '13812345678');
    expect(second.id, original.find('mobile_2')!.id);
    expect(second.profileName, original.find('mobile_2')!.profileName);
    expect(second.snapshotKey, original.find('mobile_2')!.snapshotKey);
    expect(restored.find('mobile')!.note, isNull);
  });
  test('legacy and malformed optional fields retain the account record', () {
    final legacy = jsonEncode({
      'schemaVersion': 1,
      'accounts': [
        {
          'id': 'mobile_2',
          'carrier': 'mobile',
          'label': '中国移动 2',
          'note': List.filled(21, '超').join(),
          'phoneNumber': 'bad',
        },
      ],
    });
    final restored = CarrierAccounts.restore(
      savedJson: legacy,
      selection: selection,
    );
    expect(restored.find('mobile_2'), isNotNull);
    expect(restored.find('mobile_2')!.displayName, '中国移动 2');
    expect(restored.find('mobile_2')!.phoneHint, isNull);
  });
  test(
    'empty identity clears optional values and short numbers remain masked',
    () {
      var records = CarrierAccounts.fromSelection(
        selection,
      ).updateIdentity('mobile', note: '主卡', phoneNumber: '1234567');
      expect(records.find('mobile')!.phoneHint, '1****4567');
      expect(records.find('mobile')!.phoneHint, isNot(contains('1234567')));
      records = records.withoutIdentities();
      expect(records.find('mobile')!.displayName, '中国移动 1');
      expect(records.find('mobile')!.phoneHint, isNull);
      expect(records.find('mobile')!.id, 'mobile');
    },
  );
  test('invalid identity is rejected before persistence', () {
    expect(CarrierAccount.validateNote(List.filled(20, '中').join()), isNull);
    expect(CarrierAccount.validateNote(List.filled(21, '中').join()), isNotNull);
    expect(CarrierAccount.validateNote('主卡\n工作'), isNotNull);
    expect(CarrierAccount.validatePhoneNumber('+8613812345678'), isNull);
    for (final number in [
      '123456',
      '1234567890123456',
      '138-1234-5678',
      'abcdefg',
    ]) {
      expect(CarrierAccount.validatePhoneNumber(number), isNotNull);
    }
    expect(
      () => CarrierAccounts.fromSelection(
        selection,
      ).updateIdentity('mobile', note: '主卡', phoneNumber: 'bad'),
      throwsFormatException,
    );
  });
  test(
    'currency compatibility preserves old query time across failed refresh',
    () {
      final old = CarrierSnapshot.fromJson({
        'carrier': 'mobile',
        'status': 'success',
      });
      expect(old.balanceYuan, isNull);
      final queriedAt = DateTime.utc(2026, 10, 1, 1);
      final snapshot = CarrierSnapshot(
        carrier: Carrier.telecom,
        status: QueryStatus.success,
        balanceYuan: -3.25,
        queriedAt: queriedAt,
      );
      final failed = snapshot.copyWith(status: QueryStatus.error);
      expect(failed.balanceYuan, -3.25);
      expect(failed.queriedAt, queriedAt);
      expect(CarrierSnapshot.fromJson(failed.toJson()).balanceYuan, -3.25);
      expect(failed.copyWith(balanceYuan: null).balanceYuan, isNull);
      expect(
        CarrierSnapshot.fromJson({
          ...failed.toJson(),
          'balanceYuan': double.infinity,
        }).balanceYuan,
        isNull,
      );
    },
  );
}
