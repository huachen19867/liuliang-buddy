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
      expect(one.accounts.map((a) => a.id), ['mobile']);
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
}
