/// Installation domain contracts (FS-01).
///
/// Typed forms of the F0-02 mobile bootstrap contract
/// (docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md §4). Field names and limits
/// are frozen by that contract; changing them requires a fixture freeze (F0-04)
/// and an ADR first.
library;

import 'dart:convert';

import 'installation_key_validation.dart';

/// Mobile platform values (docs/08 §4.1 `platform`).
enum NebulaPlatform { ios, android, harmony, web }

/// Server attestation verdict (docs/08 §4.2 `attestation_state`).
enum NebulaAttestationState { verified, limited, notSupported }

/// Proof-of-possession algorithm (docs/08 §4.2 `proof_algorithm`, frozen ES256).
enum NebulaProofAlgorithm { es256 }

/// Shared optional diagnostic-string cap retained for public compatibility.
/// Bootstrap V2 has field-specific 64/128-byte limits; see [BootstrapRequest].
const int nebulaStringMaxLength = 128;

/// Attestation payload cap in UTF-8 bytes (Bootstrap Contract V2).
const int nebulaAttestationMaxLength = 16 * 1024;

/// Public-key wire cap in UTF-8 bytes (Bootstrap Contract V2 / Backend).
const int nebulaPublicKeyMaxLength = 1024;

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

/// Typed bootstrap request (Bootstrap Contract V2).
///
/// `attestation` is optional nullable string platform evidence. The SDK owns
/// its wire serialization but does not interpret provider-specific contents.
final class BootstrapRequest {
  static const int _identityMaxBytes = 64;
  static const int _diagnosticMaxBytes = 128;
  static const int _routingMaxBytes = 64;
  static const int _bodyMaxBytes = 32 * 1024;

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

  /// Applies the reconciled Bootstrap Contract V2 limits.
  ///
  /// Backend caps are UTF-8 byte limits, not Dart UTF-16 code-unit counts.
  /// Optional diagnostic/routing fields may be null; when present they must be
  /// non-empty. The final canonical JSON body is also bounded by
  /// the Backend's 32 KiB request-body ceiling.
  void validate() {
    _requireUtf8(appId, 'appId', _identityMaxBytes);
    _requireUtf8(
      installationId,
      'installationId',
      _identityMaxBytes,
    );
    _requireUtf8(
      bootstrapRequestId,
      'bootstrapRequestId',
      _identityMaxBytes,
    );
    validateP256SpkiBase64Url(
      publicKey,
      maxUtf8Bytes: nebulaPublicKeyMaxLength,
    );
    _optionalUtf8(appVersion, 'appVersion', _diagnosticMaxBytes);
    _optionalUtf8(buildNumber, 'buildNumber', _diagnosticMaxBytes);
    _optionalUtf8(osVersion, 'osVersion', _diagnosticMaxBytes);
    _optionalUtf8(locale, 'locale', _routingMaxBytes);
    _optionalUtf8(region, 'region', _routingMaxBytes);
    _optionalUtf8(
      attestation,
      'attestation',
      nebulaAttestationMaxLength,
    );

    final int bodyBytes = utf8.encode(jsonEncode(_wireMap())).length;
    if (bodyBytes > _bodyMaxBytes) {
      throw ArgumentError.value(
        bodyBytes,
        'bootstrapRequest',
        'canonical JSON body must be <= $_bodyMaxBytes bytes',
      );
    }
  }

  /// Canonical SDK-owned 11-key wire representation.
  ///
  /// Optional values remain explicit JSON `null` when absent so every consumer
  /// emits the same shape; callers must not duplicate this mapping.
  Map<String, Object?> toJson() => _wireMap();

  Map<String, Object?> _wireMap() => <String, Object?>{
        'app_id': appId,
        'installation_id': installationId,
        'platform': platform.name,
        'app_version': appVersion,
        'build_number': buildNumber,
        'os_version': osVersion,
        'locale': locale,
        'region': region,
        'public_key': publicKey,
        'attestation': attestation,
        'bootstrap_request_id': bootstrapRequestId,
      };

  void _requireUtf8(String value, String field, int maxBytes) {
    final int length = utf8.encode(value).length;
    if (value.isEmpty || length > maxBytes) {
      throw ArgumentError.value(
        length,
        field,
        'must be non-empty and <= $maxBytes UTF-8 bytes',
      );
    }
  }

  void _optionalUtf8(String? value, String field, int maxBytes) {
    if (value == null) return;
    final int length = utf8.encode(value).length;
    if (value.isEmpty || length > maxBytes) {
      throw ArgumentError.value(
        length,
        field,
        'when present, must be non-empty and <= $maxBytes UTF-8 bytes',
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
      // Wire 编码（Bootstrap Contract V2）：unix 秒 int64。
      expiresAt: _unixSeconds(json['expires_at']),
      renewAfter: _unixSeconds(json['renew_after']),
      serverTime: _unixSeconds(json['server_time']),
      appId: json['app_id'] as String,
      installationId: json['installation_id'] as String,
      proofAlgorithm: _proofAlgorithmFromWire(
        json['proof_algorithm'] as String,
      ),
      attestationState: _attestationStateFromWire(
        json['attestation_state'] as String,
      ),
      minimumSupportedBuild: json['minimum_supported_build'] as String?,
      requestId: json['request_id'] as String,
    );
  }

  /// Wire 时间：unix 秒（int64）。SDK 解析为 UTC DateTime，不依赖服务器时区。
  static DateTime _unixSeconds(Object? value) {
    if (value is! int) {
      throw FormatException('wire time must be unix seconds (int64): $value');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      value * 1000,
      isUtc: true,
    );
  }

  /// Wire 算法值：`ES256`（Bootstrap Contract V2 冻结大写常量）。
  static NebulaProofAlgorithm _proofAlgorithmFromWire(String wire) {
    return switch (wire) {
      'ES256' => NebulaProofAlgorithm.es256,
      _ => throw FormatException('unknown proof_algorithm: $wire'),
    };
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
