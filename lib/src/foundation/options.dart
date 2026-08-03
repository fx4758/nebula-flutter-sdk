enum NebulaEnvironment { development, staging, production }

final class NebulaOptions {
  const NebulaOptions({
    required this.appId,
    required this.baseUri,
    required this.environment,
    this.region = 'CN',
  });

  /// Public product identifier. This is not a credential.
  final String appId;
  final Uri baseUri;
  final NebulaEnvironment environment;
  final String region;

  void validate() {
    if (appId.trim().isEmpty) {
      throw ArgumentError.value(appId, 'appId', 'must not be empty');
    }
    if (!baseUri.hasScheme || !baseUri.hasAuthority) {
      throw ArgumentError.value(baseUri, 'baseUri', 'must be absolute');
    }
    if (environment == NebulaEnvironment.production &&
        baseUri.scheme != 'https') {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'production requires HTTPS',
      );
    }
  }
}
