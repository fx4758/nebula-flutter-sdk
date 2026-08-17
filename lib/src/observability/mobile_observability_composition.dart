library;

import '../analytics/analytics_client.dart';
import '../analytics/consent.dart';
import '../analytics/mobile_analytics_sender.dart';
import '../analytics/nebula_analytics.dart';
import '../auth/proof.dart';
import '../capabilities.dart';
import '../error_reporting/cache_error_report_store.dart';
import '../error_reporting/client.dart';
import '../error_reporting/mobile_error_report_sender.dart';
import '../foundation/options.dart';
import '../storage/cache_storage.dart';
import '../transport.dart';

({NebulaAnalytics analytics, NebulaErrorReporting errorReporting})
    createMobileObservabilityComposition({
  required NebulaOptions options,
  required NebulaTransport transport,
  required RequestProofSigner proofSigner,
  required Future<String> Function() installationToken,
  required Future<bool> Function() recoverInstallationTrust,
  required CacheStorage persistentStorage,
}) {
  options.validate();

  final MobileAnalyticsSender analyticsSender = MobileAnalyticsSender(
    options: options,
    transport: transport,
    proofSigner: proofSigner,
    installationToken: installationToken,
    recoverInstallationTrust: recoverInstallationTrust,
  );
  final NebulaAnalyticsClient analytics = NebulaAnalyticsClient(
    consentStore: CacheConsentStore(
      storage: persistentStorage,
      environment: options.environment,
      appId: options.appId,
    ),
    sender: analyticsSender,
  );

  final CacheErrorReportStore errorStore = CacheErrorReportStore(
    storage: persistentStorage,
    environment: options.environment,
    appId: options.appId,
  );
  final MobileErrorReportSender errorSender = MobileErrorReportSender(
    options: options,
    transport: transport,
    proofSigner: proofSigner,
    installationToken: installationToken,
    recoverInstallationTrust: recoverInstallationTrust,
  );
  final ErrorReportingClient errorReporting = ErrorReportingClient(
    store: errorStore,
    sender: errorSender,
  );

  return (analytics: analytics, errorReporting: errorReporting);
}
