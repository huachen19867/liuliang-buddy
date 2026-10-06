part of '../flutter_secure_storage.dart';

/// Specific options for Linux platform.
/// Currently there are no specific linux options available.
class LinuxOptions extends Options {
  /// Creates an instance of `LinuxOptions` with no additional configuration.
  const LinuxOptions();

  /// A predefined `LinuxOptions` instance with default settings.
  ///
  /// This can be used as a fallback or when no specific options are required.
  static const LinuxOptions defaultOptions = LinuxOptions();

  /// Converts the `LinuxOptions` instance into a map representation.
  ///
  /// Returns:
  /// - An empty map, as `LinuxOptions` does not require additional
  /// configuration.
  ///
  /// Overrides:
  /// - [Options.toMap] to provide a Linux-specific implementation.
  @override
  Map<String, String> toMap() {
    return <String, String>{};
  }
}
