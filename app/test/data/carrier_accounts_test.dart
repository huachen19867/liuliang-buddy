import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';

void main() {
  test(
    'legacy selection becomes a primary account with unchanged storage keys',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final restored = CarrierAccounts.restore(
        savedJson: null,
        selection: selection,
      );
      final primary = restored.accounts.single;
      expect(primary.id, 'mobile');
      expect(primary.snapshotKey, 'snapshot_mobile');
      expect(primary.connectedKey, 'connected_mobile');
      expect(primary.profileName, isNull);
    },
  );

  test('second account persists independently and hidden history remains', () {
    final mobile = CarrierSelection.complete([Carrier.mobile]);
    final original = CarrierAccounts.fromSelection(
      mobile,
    ).addSecond(Carrier.mobile);
    final restored = CarrierAccounts.restore(
      savedJson: original.toStorageString(),
      selection: mobile,
    );
    expect(restored.visibleAccounts(mobile).map((a) => a.id), [
      'mobile',
      'mobile_2',
    ]);
    expect(restored.find('mobile_2')!.profileName, 'liuliang_mobile_2');
    expect(restored.find('mobile_2')!.snapshotKey, 'snapshot_mobile_2');

    final broadnetOnly = CarrierSelection.complete([Carrier.broadnet]);
    final withBroadnet = restored.ensureSelection(broadnetOnly);
    expect(withBroadnet.visibleAccounts(broadnetOnly).map((a) => a.id), [
      'broadnet',
    ]);
    expect(withBroadnet.find('mobile_2'), isNotNull);
    final reopened = withBroadnet.ensureSelection(mobile);
    expect(reopened.visibleAccounts(mobile).map((a) => a.id), [
      'mobile',
      'mobile_2',
    ]);
  });

  test(
    'removing second card keeps primary and can be readded with same id',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final both = CarrierAccounts.fromSelection(
        selection,
      ).addSecond(Carrier.mobile);
      final one = both.removeSecond('mobile_2');
      expect(one.visibleAccounts(selection).map((a) => a.id), ['mobile']);
      expect(one.find('mobile_2')!.enabled, isFalse);
      expect(one.addSecond(Carrier.mobile).accounts.map((a) => a.id), [
        'mobile',
        'mobile_2',
      ]);
    },
  );

  test('hidden accounts do not consume the four visible slots', () {
    final all = CarrierSelection.complete(Carrier.values);
    final records = CarrierAccounts.fromSelection(all);
    final hiddenTelecom = CarrierSelection.complete([
      Carrier.mobile,
      Carrier.broadnet,
      Carrier.unicom,
    ]);
    final withSecond = records.addSecond(Carrier.mobile);
    expect(withSecond.accounts, hasLength(5));
    expect(withSecond.visibleCount(hiddenTelecom), 4);
    expect(withSecond.find('telecom'), isNotNull);
    expect(() => withSecond.addSecond(Carrier.mobile), returnsNormally);
  });

  test(
    'four same-carrier accounts round trip with independent stable keys',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final accounts = CarrierAccounts.fromSelection(
        selection,
      ).withAccountCounts(selection, {Carrier.mobile: 4});
      final restored = CarrierAccounts.restore(
        savedJson: accounts.toStorageString(),
        selection: selection,
      );
      expect(restored.visibleAccounts(selection).map((a) => a.id), [
        'mobile',
        'mobile_2',
        'mobile_3',
        'mobile_4',
      ]);
      for (var slot = 2; slot <= 4; slot++) {
        final account = restored.find('mobile_$slot')!;
        expect(account.profileName, 'liuliang_mobile_$slot');
        expect(account.connectedKey, 'connected_mobile_$slot');
        expect(account.snapshotKey, 'snapshot_mobile_$slot');
      }
      expect(restored.find('mobile')!.profileName, isNull);
    },
  );

  test(
    'reducing and readding keeps hidden identities and does not renumber gaps',
    () {
      final selection = CarrierSelection.complete([Carrier.broadnet]);
      final accounts = CarrierAccounts.fromSelection(selection)
          .withCount(Carrier.broadnet, 4)
          .updateIdentity('broadnet_2', note: '家人', phoneNumber: '13800138000')
          .updateIdentity('broadnet_4', note: '工作', phoneNumber: '13900139000');
      final gap = accounts.removeSecond('broadnet_2');
      expect(gap.visibleAccounts(selection).map((a) => a.id), [
        'broadnet',
        'broadnet_3',
        'broadnet_4',
      ]);
      final smaller = gap.withCount(Carrier.broadnet, 1);
      final restored = CarrierAccounts.restore(
        savedJson: smaller.toStorageString(),
        selection: selection,
      );
      expect(restored.accounts, hasLength(4));
      expect(restored.visibleCount(selection), 1);
      final reopened = restored.withCount(Carrier.broadnet, 4);
      expect(reopened.find('broadnet_2')!.note, '家人');
      expect(reopened.find('broadnet_4')!.note, '工作');
      expect(
        reopened.find('broadnet_4')!.broadnetSessionKey,
        'broadnet_session_broadnet_4',
      );
    },
  );

  test(
    'mixed carriers obey four visible limit while retaining old histories',
    () {
      final all = CarrierSelection.complete(Carrier.values);
      var accounts = CarrierAccounts.fromSelection(all);
      for (final carrier in Carrier.values) {
        accounts = accounts.withCount(carrier, 4);
      }
      final selected = CarrierSelection.complete([
        Carrier.mobile,
        Carrier.unicom,
      ]);
      final mixed = accounts.withAccountCounts(selected, {
        Carrier.mobile: 3,
        Carrier.unicom: 1,
      });
      expect(mixed.visibleCount(selected), 4);
      expect(mixed.accounts, hasLength(16));
      expect(mixed.visibleAccounts(selected).map((a) => a.id), [
        'mobile',
        'mobile_2',
        'mobile_3',
        'unicom',
      ]);
      expect(
        () => mixed.withAccountCounts(selected, {
          Carrier.mobile: 4,
          Carrier.unicom: 1,
        }),
        throwsStateError,
      );
      expect(() => mixed.withCount(Carrier.mobile, 5), throwsRangeError);
    },
  );

  test(
    'legacy records missing enabled stay active; untrusted slot IDs are rejected',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final legacy = jsonEncode({
        'schemaVersion': 1,
        'accounts': [
          {'id': 'mobile', 'carrier': 'mobile', 'label': '中国移动 1'},
          {
            'id': 'mobile_2',
            'carrier': 'mobile',
            'label': '中国移动 2',
            'note': '旧备注',
          },
        ],
      });
      final restored = CarrierAccounts.restore(
        savedJson: legacy,
        selection: selection,
      );
      expect(restored.visibleCount(selection), 2);
      expect(restored.find('mobile_2')!.note, '旧备注');
      for (final id in ['mobile_1', 'mobile_5', 'mobile_02', 'unicom_3']) {
        expect(
          CarrierAccount.fromJson({
            'id': id,
            'carrier': 'mobile',
            'label': '伪记录',
          }),
          isNull,
        );
      }
    },
  );
}
