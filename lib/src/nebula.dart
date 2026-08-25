import 'analytics/nebula_analytics.dart';
import 'foundation/request_proof.dart';
import 'capabilities.dart';
import 'config/nebula_config.dart';
import 'foundation/options.dart';
import 'observability/mobile_observability_composition.dart';
import 'storage/cache_storage.dart';
import 'transport.dart';

/// Dependency-injected facade. It intentionally contains no service locator.
final class Nebula {
  Nebula({
    required NebulaOptions options,
    required this.transport,
    required this.auth,
    required this.config,
    required this.analytics,
    this.errorReporting,
  }) : options = options {
    options.validate();
  }

  final NebulaOptions options;
  final NebulaTransport transport;
  final NebulaAuth auth;
  final NebulaConfig config;
  final NebulaAnalytics analytics;
  final NebulaErrorReporting? errorReporting;
}

/// SDK-owned Mobile Observability composition root.
final class NebulaMobileObservability {
  NebulaMobileObservability._({
    required this.analytics,
    required this.errorReporting,
    required Future<void> Function() flush,
  }) : _flush = flush;

  final NebulaAnalytics analytics;
  final NebulaErrorReporting errorReporting;
  final Future<void> Function() _flush;

  /// Offers both observability domains one best-effort delivery opportunity.
  ///
  /// The host owns when lifecycle opportunities occur. The SDK keeps queue,
  /// retry, trust recovery, ACK and domain failure handling internal.
  Future<void> flush() => _flush();

  static NebulaMobileObservability create({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required Future<bool> Function() recoverInstallationTrust,
    required CacheStorage persistentStorage,
  }) {
    final ({
      NebulaAnalytics analytics,
      NebulaErrorReporting errorReporting,
      Future<void> Function() flush,
    }) composed = createMobileObservabilityComposition(
      options: options,
      transport: transport,
      proofSigner: proofSigner,
      installationToken: installationToken,
      recoverInstallationTrust: recoverInstallationTrust,
      persistentStorage: persistentStorage,
    );
    return NebulaMobileObservability._(
      analytics: composed.analytics,
      errorReporting: composed.errorReporting,
      flush: composed.flush,
    );
  }
}
