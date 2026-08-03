/// Secure token store Port (FS-01).
///
/// Storage contract for installation/refresh tokens (docs/08 §6.2 storage
/// column): installation token and refresh token live in secure storage only.
/// The SDK core defines the Port plus an environment/App namespace rule; the
/// concrete secure-store plugin is supplied by the host app (no Provider SDK
/// dependency here).
library;

import '../foundation/options.dart';

/// Token store keys (docs/08 §6.2 item names).
const String tokenKeyInstallation = 'installation_token';
const String tokenKeyRefresh = 'refresh_token';

/// Builds the storage namespace for an environment/App pair (FS-01).
///
/// Example: `staging:com.example.app`. Namespacing prevents cross-environment
/// or cross-App token leakage when several builds share one device.
String tokenNamespace(NebulaEnvironment environment, String appId) =>
    '${environment.name}:$appId';

/// Secure token store Port.
///
/// All values are opaque strings at this layer (tokens, not user content).
/// Implementations MUST NOT log values or include them in error messages
/// (docs/08 §6.2: raw tokens are never logged).
abstract interface class SecureTokenStore {
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

  /// Clears every key under one namespace (e.g. local logout for a single
  /// environment/App; docs/08 §6.4 logout is scoped, not "all devices").
  Future<void> clearNamespace(String namespace);
}

/// In-memory fake used by tests.
///
/// Not a production implementation: plain `Map` storage, no OS keychain.
final class InMemoryTokenStore implements SecureTokenStore {
  final Map<String, Map<String, String>> _namespaces =
      <String, Map<String, String>>{};

  @override
  Future<String?> read({
    required String namespace,
    required String key,
  }) async {
    return _namespaces[namespace]?[key];
  }

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
