part of '../flutter_secure_storage.dart';

/// Specific options for Windows platform.
class WindowsOptions extends Options {
  /// * If `useBackwardCompatibility` is set to true, trying to read from values
  ///   which were written by previous versions. In addition, when reading or
  ///   writing from previous version's storage, read values will be migrated to
  ///   new storage automatically. This may introduces some performance hit and
  ///   might cause error for some kinds of keys.
  ///   Default is `false`.
  ///   You must set this value to `false` if you could use:
  ///   * Keys containing `"`, `<`, `>`, `|`, `:`, `*`, `?`, `/`, `\`,
  ///     or any of ASCII control charactors.
  ///   * Keys containing `/../`, `\..\`, or their combinations.
  ///   * Long key string (precise size is depends on your app's product name,
  ///     company name, and account name who executes your app).
  ///
  /// You can migrate all old data with this options as following:
  /// ```dart
  /// await FlutterSecureStorage().readAll(
  ///     const WindowsOptions(useBackwardCompatibility: true),
  /// );
  /// ```
  const WindowsOptions({
    bool useBackwardCompatibility = false,
  }) : _useBackwardCompatibility = useBackwardCompatibility;

  /// A predefined `WindowsOptions` instance with default settings.
  ///
  /// This can be used as a fallback or when no specific options are required.
  static const WindowsOptions defaultOptions = WindowsOptions();

  final bool _useBackwardCompatibility;

  @override
  Map<String, String> toMap() => <String, String>{
    'useBackwardCompatibility': _useBackwardCompatibility.toString(),
  };

  /// Creates a new instance of `WindowsOptions` by copying the current instance
  /// and replacing specified properties with new values.
  WindowsOptions copyWith({
    bool? useBackwardCompatibility,
  }) => WindowsOptions(
    useBackwardCompatibility:
        useBackwardCompatibility ?? _useBackwardCompatibility,
  );
}
