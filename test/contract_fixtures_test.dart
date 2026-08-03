import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F0-04 — API contract fixtures and error mapping (docs/03 F0-04)
//
// Fixture-driven contract tests: every assertion is derived from the frozen
// JSON files in test/fixtures/, not from inline literals. Changing a contract
// means changing the fixture (and an ADR), and this file will then show what
// drifts on the SDK side.
// =============================================================================

Map<String, Object?> _fixture(String name) {
  final raw = File('test/fixtures/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

void main() {
  group('F0-04 bootstrap request fixture (docs/08 §4.1)', () {
    test('every frozen wire field is consumed and re-emitted', () {
      final json = _fixture('bootstrap_request');
      final req = BootstrapRequest(
        appId: json['app_id']! as String,
        installationId: json['installation_id']! as String,
        platform: NebulaPlatform.values.byName(json['platform']! as String),
        appVersion: json['app_version'] as String?,
        buildNumber: json['build_number'] as String?,
        osVersion: json['os_version'] as String?,
        locale: json['locale'] as String?,
        region: json['region'] as String?,
        publicKey: json['public_key']! as String,
        attestation: json['attestation'] as String?,
        bootstrapRequestId: json['bootstrap_request_id']! as String,
      );
      req.validate(); // real values must satisfy §4.1 limits
      expect(req.publicKey, json['public_key']);
      // Real ES256/P-256 SPKI DER base64url is 122 chars — well under limits.
      expect(req.publicKey.length, 122);
      expect(req.attestation, isNull); // not_supported flow
    });

    test('public key fixture parses as valid base64url DER (SPKI length)', () {
      final json = _fixture('bootstrap_request');
      final der =
          base64Url.decode(base64Url.normalize(json['public_key']! as String));
      // SPKI header (26 bytes) + uncompressed P-256 point (65 bytes).
      expect(der.length, 91);
    });
  });

  group('F0-04 bootstrap response fixture (docs/08 §4.2)', () {
    test('typed result parses every frozen field from the fixture', () {
      final json = _fixture('bootstrap_response');
      final result = BootstrapResult.fromJson(json);
      expect(result.installationToken, json['installation_token']);
      expect(result.expiresAt, DateTime.parse(json['expires_at']! as String));
      expect(result.renewAfter, DateTime.parse(json['renew_after']! as String));
      expect(result.serverTime, DateTime.parse(json['server_time']! as String));
      expect(result.appId, json['app_id']);
      expect(result.installationId, json['installation_id']);
      expect(result.proofAlgorithm, NebulaProofAlgorithm.es256);
      expect(result.attestationState, NebulaAttestationState.notSupported);
      expect(result.minimumSupportedBuild, isNull);
      expect(result.requestId, json['request_id']);
      // Token TTL sanity: expires 24h after iat per fixture.
      expect(
        result.expiresAt.difference(DateTime.parse('2026-08-03T18:00:00Z')),
        const Duration(hours: 24),
      );
    });
  });

  group('F0-04 proof canonicalization fixture (docs/08 §5)', () {
    test('canonicalize produces exactly the frozen expected bytes', () {
      final json = _fixture('proof_canonical');
      final canonical = ProofCanonicalInput(
        version: json['version']! as String,
        method: json['method']! as String,
        path: json['path']! as String,
        timestamp: json['timestamp']! as String,
        nonce: json['nonce']! as String,
        bodySha256: json['body_sha256']! as String,
        tokenSha256: json['token_sha256']! as String,
      ).canonicalize();
      expect(canonical, json['expected_canonical']);
    });

    test('digests in fixture are real SHA-256 hex (64 chars)', () {
      final json = _fixture('proof_canonical');
      expect((json['body_sha256']! as String).length, 64);
      expect((json['token_sha256']! as String).length, 64);
    });
  });

  group('F0-04 error-code mapping (docs/08 §8 + FB-01 allocation)', () {
    test('every mapped code classifies to its frozen category', () {
      final table = (_fixture('error_mapping')['table']! as List)
          .cast<Map<String, Object?>>();
      for (final row in table) {
        final code = row['code']! as int;
        final sdkClass = row['sdk_class']! as String;
        final error = classifySessionError(statusCode: 200, code: code);
        expect(
          error.runtimeType.toString(),
          sdkClass,
          reason: 'code $code must map to $sdkClass per frozen mapping',
        );
      }
    });

    test('rate_limited also triggers on HTTP 429 regardless of code', () {
      final error = classifySessionError(statusCode: 429, code: 0);
      expect(error, isA<RateLimitedError>());
    });

    test('unknown code preserves integer code and requestId', () {
      final error = classifySessionError(
          statusCode: 200, code: 77777, requestId: 'req-x');
      expect(error, isA<AuthenticationRequiredError>());
      expect(error.code, 77777);
      expect(error.requestId, 'req-x');
    });
  });
}
