/// Cache storage Port (F1-03).
///
/// Non-sensitive, replayable cached bytes (config blobs, feature flags,
/// previews). Values are opaque bytes; the caller owns (de)serialization and
/// TTL semantics. The SDK core defines the Port plus the namespace rule; the
/// concrete implementation (in-memory, disk LRU, etc.) is supplied by the host
/// (docs/01 §4: pure-Dart core must not depend on a specific plugin).
library;

import 'dart:typed_data';

/// Cache storage Port.
///
/// Stores opaque bytes (NOT secrets — use [SecureStorage] for tokens). The
/// optional [ttl] on [write] is a hint: implementations SHOULD treat the entry
/// as expired after `ttl` from write time. Implementations MUST NOT log values.
abstract interface class CacheStorage {
  Future<Uint8List?> read({
    required String namespace,
    required String key,
  });

  Future<void> write({
    required String namespace,
    required String key,
    required Uint8List value,
    Duration? ttl,
  });

  Future<void> delete({
    required String namespace,
    required String key,
  });

  /// Clears every key under one namespace.
  Future<void> clearNamespace(String namespace);
}

final class _CacheEntry {
  _CacheEntry(this.bytes, this.expiresAt);
  final Uint8List bytes;
  final DateTime? expiresAt;
}

/// In-memory fake used by tests and as a reference behavior sketch.
///
/// Not a production implementation. This fake enforces [CacheStorage.write]'s
/// [ttl] hint on read (returns null after expiry) as a reference behavior;
/// production implementations may differ but SHOULD honor the hint.
final class InMemoryCacheStorage implements CacheStorage {
  InMemoryCacheStorage();

  final Map<String, Map<String, _CacheEntry>> _namespaces =
      <String, Map<String, _CacheEntry>>{};

  @override
  Future<Uint8List?> read({
    required String namespace,
    required String key,
  }) async {
    final Map<String, _CacheEntry>? bucket = _namespaces[namespace];
    if (bucket == null) return null;
    final _CacheEntry? entry = bucket[key];
    if (entry == null) return null;
    if (entry.expiresAt != null && DateTime.now().isAfter(entry.expiresAt!)) {
      bucket.remove(key);
      return null;
    }
    return entry.bytes;
  }

  @override
  Future<void> write({
    required String namespace,
    required String key,
    required Uint8List value,
    Duration? ttl,
  }) async {
    final DateTime? expiresAt = ttl == null ? null : DateTime.now().add(ttl);
    _namespaces.putIfAbsent(namespace, () => <String, _CacheEntry>{})[key] =
        _CacheEntry(value, expiresAt);
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
