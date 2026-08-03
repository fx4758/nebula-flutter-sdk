/// Installation domain contracts (FS-01).
///
/// Typed forms of the F0-02 mobile bootstrap contract
/// (docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md §4). Field names and limits
/// are frozen by that contract; changing them requires a fixture freeze (F0-04)
/// and an ADR first.
library;

/// Mobile platform values (docs/08 §4.1 `platform`).
enum NebulaPlatform { ios, android, harmony, web }

/// Server attestation verdict (docs/08 §4.2 `attestation_state`).
enum NebulaAttestationState { verified, limited, notSupported }

/// Proof-of-possession algorithm (docs/08 §4.2 `proof_algorithm`, frozen ES256).
enum NebulaProofAlgorithm { es256 }

/// Shared string cap from docs/08 §4.1 ("string maximum: 128 characters").
const int nebulaStringMaxLength = 128;

/// Attestation payload cap from docs/08 §4.1 ("attestation maximum: 16 KiB").
const int nebulaAttestationMaxLength = 16 * 1024;

/// Public key payload cap. ES256/P-256 SPKI DER base64url stays well under
/// this; the generous cap avoids a hard dependency on the exact key encoding,
/// which F0-04 fixtures will pin down later.
const int nebulaPublicKeyMaxLength = 4096;

/// A bound installation identity: App + installation + key thumbprint.
///
/// The private key never leaves the platform secure key store; this object
/// only carries the public side (docs/08 §6.2: installation private key is
/// non-exportable when available).
final class InstallationIdentity {
  const InstallationIdentity({
    required this.appId,
    required this.installationId,
    required this.platform,
    this.publicKeyThumbprint,
  });

  final String appId;
  final String installationId;
  final NebulaPlatform platform;
  final String? publicKeyThumbprint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallationIdentity &&
          appId == other.appId &&
          installationId == other.installationId &&
          platform == other.platform &&
          publicKeyThumbprint == other.publicKeyThumbprint;

  @override
  int get hashCode =>
      Object.hash(appId, installationId, platform, publicKeyThumbprint);

  @override
  String toString() => 'InstallationIdentity($appId/$installationId)';
}

/// Typed bootstrap request (docs/08 §4.1).
///
/// `attestation` stays opaque at this layer: its typed shape is platform
/// evidence and is pinned by F0-04 fixtures, not by the SDK core.
final class BootstrapRequest {
  const BootstrapRequest({
    required this.appId,
    required this.installationId,
    required this.platform,
    required this.publicKey,
    required this.bootstrapRequestId,
    this.appVersion,
    this.buildNumber,
    this.osVersion,
    this.locale,
    this.region,
    this.attestation,
  });

  final String appId;
  final String installationId;
  final NebulaPlatform platform;
  final String publicKey;
  final String bootstrapRequestId;
  final String? appVersion;
  final String? buildNumber;
  final String? osVersion;
  final String? locale;

  /// Routing hint only — never trusted for authorization (docs/08 §4.1).
  final String? region;
  final String? attestation;

  /// Applies the frozen limits from docs/08 §4.1.
  ///
  /// Throws [ArgumentError] on the first violation. String fields default to
  /// 128 chars; attestation is capped at 16 KiB and publicKey at 4096 chars.
  void validate() {
    _requireBounded(appId, 'appId');
    _requireBounded(installationId, 'installationId');
    _requireBounded(bootstrapRequestId, 'bootstrapRequestId');
    if (publicKey.isEmpty || publicKey.length > nebulaPublicKeyMaxLength) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey',
        'must be non-empty and <= $nebulaPublicKeyMaxLength chars',
      );
    }
    if (attestation != null &&
        (attestation!.isEmpty ||
            attestation!.length > nebulaAttestationMaxLength)) {
      throw ArgumentError.value(
        attestation!.length,
        'attestation',
        'must be non-empty and <= $nebulaAttestationMaxLength chars',
      );
    }
    for (final f in <String?>[
      appVersion,
      buildNumber,
      osVersion,
      locale,
      region
    ]) {
      if (f != null) _requireBounded(f, 'optional string');
    }
  }

  void _requireBounded(String value, String field) {
    if (value.isEmpty || value.length > nebulaStringMaxLength) {
      throw ArgumentError.value(
        value.length,
        field,
        'must be non-empty and <= $nebulaStringMaxLength chars',
      );
    }
  }
}

/// Typed bootstrap response (docs/08 §4.2).
final class BootstrapResult {
  const BootstrapResult({
    required this.installationToken,
    required this.expiresAt,
    required this.renewAfter,
    required this.serverTime,
    required this.appId,
    required this.installationId,
    required this.proofAlgorithm,
    required this.attestationState,
    required this.requestId,
    this.minimumSupportedBuild,
  });

  factory BootstrapResult.fromJson(Map<String, Object?> json) {
    return BootstrapResult(
      installationToken: json['installation_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      renewAfter: DateTime.parse(json['renew_after'] as String),
      serverTime: DateTime.parse(json['server_time'] as String),
      appId: json['app_id'] as String,
      installationId: json['installation_id'] as String,
      proofAlgorithm:
          NebulaProofAlgorithm.values.byName(json['proof_algorithm'] as String),
      attestationState: _attestationStateFromWire(
        json['attestation_state'] as String,
      ),
      minimumSupportedBuild: json['minimum_supported_build'] as String?,
      requestId: json['request_id'] as String,
    );
  }

  /// Maps the server wire value (snake_case, docs/08 §4.2) to the Dart enum.
  static NebulaAttestationState _attestationStateFromWire(String wire) {
    return switch (wire) {
      'verified' => NebulaAttestationState.verified,
      'limited' => NebulaAttestationState.limited,
      'not_supported' => NebulaAttestationState.notSupported,
      _ => throw FormatException('unknown attestation_state: $wire'),
    };
  }

  final String installationToken;

  /// Token validity end (docs/08 §4.3: 24 h default, server may shorten).
  final DateTime expiresAt;

  /// Client renews at ~80% TTL with jitter; server returns the exact point.
  final DateTime renewAfter;
  final DateTime serverTime;
  final String appId;
  final String installationId;
  final NebulaProofAlgorithm proofAlgorithm;
  final NebulaAttestationState attestationState;

  /// Optional server policy: minimum store build (docs/08 §4.2).
  final String? minimumSupportedBuild;
  final String requestId;
}
