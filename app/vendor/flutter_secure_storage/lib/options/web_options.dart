part of '../flutter_secure_storage.dart';

/// Specific options for web platform.
class WebOptions extends Options {
  /// Creates an instance of `WebOptions` with configurable parameters
  /// for secure storage behavior on web platforms.
  ///
  /// Parameters:
  /// - [dbName]: The name of the database used for secure storage.
  ///   Defaults to `'FlutterEncryptedStorage'`.
  /// - [publicKey]: The public key used for encryption. Defaults to
  ///   `'FlutterSecureStorage'`.
  /// - [wrapKey]: The key used to wrap the encryption key.
  /// - [wrapKeyIv]: The initialization vector (IV) used for the wrap key.
  /// - [useSessionStorage]: Whether to use session storage instead of local
  ///   storage.
  ///   Defaults to `false`.
  const WebOptions({
    this.dbName = 'FlutterEncryptedStorage',
    this.publicKey = 'FlutterSecureStorage',
    this.wrapKey = '',
    this.wrapKeyIv = '',
    this.useSessionStorage = false,
  });

  /// A predefined `WebOptions` instance with default settings.
  ///
  /// This can be used as a fallback or when no specific options are required.
  static const WebOptions defaultOptions = WebOptions();

  /// The name of the database used for secure storage.
  /// Defaults to `'FlutterEncryptedStorage'`.
  final String dbName;

  /// The public key used for encryption.
  /// Defaults to `'FlutterSecureStorage'`.
  final String publicKey;

  /// The key used to wrap the encryption key.
  final String wrapKey;

  /// The initialization vector (IV) used for the wrap key.
  final String wrapKeyIv;

  /// Whether to use session storage instead of local storage.
  /// Defaults to `false`.
  final bool useSessionStorage;

  /// Converts the `WebOptions` instance into a map representation,
  /// including all web-specific properties.
  @override
  Map<String, String> toMap() => <String, String>{
    'dbName': dbName,
    'publicKey': publicKey,
    'wrapKey': wrapKey,
    'wrapKeyIv': wrapKeyIv,
    'useSessionStorage': useSessionStorage.toString(),
  };
}
