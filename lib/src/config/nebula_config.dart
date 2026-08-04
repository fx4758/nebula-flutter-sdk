/// Effective config capability Port (F2-01).
///
/// The single capability a host App calls at startup (docs/12 §12). It hides
/// the wire details: fetch, ETag/304 revalidation, TTL fresh window,
/// stale-if-error, security-critical no-stale, single-flight dedup and
/// kill-switch handling. Errors are the typed transport errors (code +
/// requestId preserved) and can be classified via [NebulaErrorCategory]
/// (F1-04) / the frozen error mapping (docs/12 §7).
library;

import '../transport/cancellation_token.dart';
import 'effective_config.dart';

/// Effective config capability (docs/12 §12).
abstract interface class NebulaConfig {
  /// Returns the current effective config, fetching or serving cache as the
  /// cache semantics (§6) dictate. Concurrent callers share one in-flight
  /// fetch (single-flight); idempotent GET is bounded-retried (docs/02 §3,
  /// max 2 attempts, exponential backoff + jitter); a kill-switch response
  /// (12004) is surfaced as a classified error and never cached.
  Future<NebulaEffectiveConfig> getEffectiveConfig({
    NebulaCancellationToken? cancellationToken,
  });

  /// Last known revision, or null before the first successful fetch.
  String? get revision;

  /// Discards the cached snapshot (memory + optional [CacheStorage]) so the
  /// next call refetches. Hosts call this on environment/App switch or
  /// sign-out hygiene (docs/02 §2: switching environments must not reuse
  /// cached state).
  Future<void> clearCache();
}
