import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';

void main() {
  test('completed setup requires at least one and removes duplicates', () {
    expect(() => CarrierSelection.complete([]), throwsArgumentError);
    final selected = CarrierSelection.complete([
      Carrier.broadnet,
      Carrier.broadnet,
      Carrier.mobile,
    ]);
    expect(selected.setupCompleted, isTrue);
    expect(selected.selectedCarriers.toList(), Carrier.values);
  });

  test('selection persists names and rejects unknown or future versions', () {
    final original = CarrierSelection.complete([Carrier.broadnet]);
    final restored = CarrierSelection.restore(
      savedJson: original.toStorageString(),
      legacyPreferences: {'connected_mobile': true},
    );
    expect(restored.selectedCarriers, {Carrier.broadnet});
    expect(restored.allows(Carrier.mobile), isFalse);

    for (final json in [
      '{"schemaVersion":2,"setupCompleted":true,"selectedCarriers":["mobile"]}',
      '{"schemaVersion":1,"setupCompleted":true,"selectedCarriers":["future"]}',
      '{"schemaVersion":1,"setupCompleted":true,"selectedCarriers":[]}',
      'not json',
    ]) {
      final invalid = CarrierSelection.restore(
        savedJson: json,
        legacyPreferences: {'connected_mobile': true},
      );
      expect(invalid.setupCompleted, isFalse);
      expect(invalid.selectedCarriers, isEmpty);
    }
  });

  test('legacy migration follows connected flags, not a fixed pair', () {
    final one = CarrierSelection.restore(
      savedJson: null,
      legacyPreferences: {
        'connected_mobile': false,
        'connected_broadnet': true,
        'snapshot_mobile': 'stale data is not authorization',
      },
    );
    expect(one.selectedCarriers, {Carrier.broadnet});
    expect(one.setupCompleted, isTrue);

    final unused = CarrierSelection.restore(
      savedJson: null,
      legacyPreferences: {},
    );
    expect(unused.setupCompleted, isFalse);
    expect(unused.selectedCarriers, isEmpty);
  });

  test(
    'hidden carriers cannot enter query or visible snapshot projections',
    () {
      final selected = CarrierSelection.complete([Carrier.mobile]);
      expect(
        selected.queryableCarriers([
          Carrier.broadnet,
          Carrier.mobile,
          Carrier.broadnet,
        ]),
        [Carrier.mobile],
      );
      final snapshots = [
        const CarrierSnapshot(
          carrier: Carrier.broadnet,
          status: QueryStatus.success,
          buckets: [
            TrafficBucket(
              name: '私有旧余额',
              kind: BucketKind.unknown,
              remainingBytes: 12345,
            ),
          ],
        ),
        const CarrierSnapshot(
          carrier: Carrier.mobile,
          status: QueryStatus.notConnected,
        ),
      ];
      expect(selected.visibleSnapshots(snapshots).map((item) => item.carrier), [
        Carrier.mobile,
      ]);
      expect(
        CarrierSelection.unconfigured().visibleSnapshots(snapshots),
        isEmpty,
      );
    },
  );
}
