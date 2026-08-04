import 'capabilities.dart';
import 'config/nebula_config.dart';
import 'foundation/options.dart';
import 'transport.dart';

/// Dependency-injected facade. It intentionally contains no service locator.
final class Nebula {
  Nebula({
    required NebulaOptions options,
    required this.transport,
    required this.auth,
    required this.config,
    required this.analytics,
  }) : options = options {
    options.validate();
  }

  final NebulaOptions options;
  final NebulaTransport transport;
  final NebulaAuth auth;
  final NebulaConfig config;
  final NebulaAnalytics analytics;
}
