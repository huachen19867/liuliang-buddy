import 'dart:convert';

import 'models.dart';

/// The user's explicit carrier choice. An incomplete choice authorizes no query.
class CarrierSelection {
  CarrierSelection._(this.setupCompleted, Set<Carrier> selected)
    : selectedCarriers = Set.unmodifiable(
        Carrier.values.where(selected.contains),
      );

  static const schemaVersion = 1;

  final bool setupCompleted;
  final Set<Carrier> selectedCarriers;

  factory CarrierSelection.unconfigured() => CarrierSelection._(false, {});

  factory CarrierSelection.complete(Iterable<Carrier> selected) {
    final unique = selected.toSet();
    if (unique.isEmpty) {
      throw ArgumentError.value(
        selected,
        'selected',
        'Select at least one carrier',
      );
    }
    return CarrierSelection._(true, unique);
  }

  bool allows(Carrier carrier) =>
      setupCompleted && selectedCarriers.contains(carrier);

  List<Carrier> queryableCarriers(Iterable<Carrier> connected) {
    final active = connected.toSet();
    return Carrier.values
        .where((carrier) => allows(carrier) && active.contains(carrier))
        .toList(growable: false);
  }

  /// Pass only this projection to dashboard and widget serialization.
  List<CarrierSnapshot> visibleSnapshots(Iterable<CarrierSnapshot> snapshots) {
    final byCarrier = <Carrier, CarrierSnapshot>{};
    for (final snapshot in snapshots) {
      if (allows(snapshot.carrier)) {
        byCarrier.putIfAbsent(snapshot.carrier, () => snapshot);
      }
    }
    return Carrier.values
        .where(allows)
        .map((carrier) => byCarrier[carrier])
        .whereType<CarrierSnapshot>()
        .toList(growable: false);
  }

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'setupCompleted': setupCompleted,
    'selectedCarriers': [
      for (final carrier in Carrier.values)
        if (selectedCarriers.contains(carrier)) carrier.name,
    ],
  };

  String toStorageString() => jsonEncode(toJson());

  /// Invalid or future-version data stays unconfigured rather than guessing.
  factory CarrierSelection.fromJson(Object? value) {
    if (value is! Map ||
        value['schemaVersion'] != schemaVersion ||
        value['setupCompleted'] is! bool ||
        value['selectedCarriers'] is! List) {
      return CarrierSelection.unconfigured();
    }
    final names = value['selectedCarriers'] as List;
    if (names.any((name) => name is! String)) {
      return CarrierSelection.unconfigured();
    }
    final lookup = {
      for (final carrier in Carrier.values) carrier.name: carrier,
    };
    if (names.any((name) => !lookup.containsKey(name))) {
      return CarrierSelection.unconfigured();
    }
    if (value['setupCompleted'] == false) {
      return CarrierSelection.unconfigured();
    }
    final carriers = names.map((name) => lookup[name]!).toSet();
    return carriers.isEmpty
        ? CarrierSelection.unconfigured()
        : CarrierSelection.complete(carriers);
  }

  /// Only a missing new preference triggers legacy migration. Corrupt new
  /// data must not reactivate carriers that the user previously hid.
  factory CarrierSelection.restore({
    required String? savedJson,
    required Map<String, Object?> legacyPreferences,
  }) {
    if (savedJson == null) {
      return CarrierSelection.migrateLegacyConnectedFlags(legacyPreferences);
    }
    try {
      return CarrierSelection.fromJson(jsonDecode(savedJson));
    } catch (_) {
      return CarrierSelection.unconfigured();
    }
  }

  /// Existing `connected_<carrier>` flags reflect earlier connections.
  /// No flag means setup has never been completed, not "all carriers".
  factory CarrierSelection.migrateLegacyConnectedFlags(
    Map<String, Object?> preferences,
  ) {
    final connected = Carrier.values
        .where((carrier) => preferences['connected_${carrier.name}'] == true)
        .toSet();
    return connected.isEmpty
        ? CarrierSelection.unconfigured()
        : CarrierSelection.complete(connected);
  }
}
