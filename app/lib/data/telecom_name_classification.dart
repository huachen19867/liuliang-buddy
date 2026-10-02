import 'models.dart';

/// Telecom's rendered rows provide a package name, without an official purpose
/// field. Only the literal name marker approved by the user identifies directed
/// traffic; domestic, exclusive and volume labels remain other traffic.
BucketKind classifyTelecomTrafficName(String name) =>
    name.contains('定向') ? BucketKind.directed : BucketKind.unknown;
