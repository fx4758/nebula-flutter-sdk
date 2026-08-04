/// Runtime-config endpoint configuration (F2-01, docs/12 §1).
library;

/// Target endpoint paths for the mobile runtime-config capability.
///
/// Defaults match the frozen flypost FB-06 route (docs/12 §1); hosts that run
/// behind a gateway prefix may override.
final class ConfigEndpoints {
  const ConfigEndpoints({
    this.runtimeConfig = '/api/v1/mobile/runtime-config',
  });

  final String runtimeConfig;
}
