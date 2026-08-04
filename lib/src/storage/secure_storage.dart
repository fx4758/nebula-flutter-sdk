/// Secure storage Port (F1-03).
///
/// General-purpose secure key/value store for opaque strings (tokens, small
/// secrets, serialized credentials). The SDK core defines the Port plus the
/// namespace rule; the concrete OS-backed implementation (Keychain/Keystore, or
/// a `nebula_secure_storage_flutter` adapter) is supplied by the host app
/// (docs/01 §4: pure-Dart core must not depend on a specific plugin).
///
/// Relationship to the token store: the existing [SecureTokenStore] (FS-01) has
/// the identical shape and is the token-specialized form. New non-token secrets
/// should use [SecureStorage].
library;

/// Secure storage Port.
///
/// All values are opaque strings. Implementations MUST NOT log values, keys, or
/// include them in error messages (docs/02 §4 privacy; docs/08 §6.2: raw
/// tokens are never logged).
abstract interface class SecureStorage {
  Future<String?> read({
    required String namespace,
    required String key,
  });

  Future<void> write({
    required String namespace,
    required String key,
    required String value,
  });

  Future<void> delete({
    required String namespace,
    required String key,
  });

  /// Clears every key under one namespace (scoped logout for a single
  /// environment/App/user, not "all devices").
  Future<void> clearNamespace(String namespace);
}

/// In-memory fake used by tests and as a reference behavior sketch.
///
/// Not a production implementation: plain `Map` storage, no OS keychain/crypto.
final class InMemorySecureStorage implements SecureStorage {
  InMemorySecureStorage();

  final Map<String, Map<String, String>> _namespaces =
      <String, Map<String, String>>{};

  @override
  Future<String?> read({
    required String namespace,
    required String key,
  }) async =>
      _namespaces[namespace]?[key];

  @override
  Future<void> write({
    required String namespace,
    required String key,
    required String value,
  }) async {
    _namespaces.putIfAbsent(namespace, () => <String, String>{})[key] = value;
  }

  @override
  Future<void> delete({
    required String namespace,
    required String key,
  }) async {
    _namespaces[namespace]?.remove(key);
  }

  @override
  Future<void> clearNamespace(String namespace) async {
    _namespaces.remove(namespace);
  }
}
