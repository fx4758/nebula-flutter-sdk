import 'dart:convert';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

import 'bootstrap_test_support.dart';

void main() {
  group('InstallationIdentity', () {
    test('equality compares app/installation/platform/thumbprint', () {
      const a = InstallationIdentity(
        appId: 'app-a',
        installationId: 'inst-1',
        platform: NebulaPlatform.ios,
        publicKeyThumbprint: 'fp-1',
      );
      const same = InstallationIdentity(
        appId: 'app-a',
        installationId: 'inst-1',
        platform: NebulaPlatform.ios,
        publicKeyThumbprint: 'fp-1',
      );
      const differentInstallation = InstallationIdentity(
        appId: 'app-a',
        installationId: 'inst-2',
        platform: NebulaPlatform.ios,
        publicKeyThumbprint: 'fp-1',
      );
      expect(a, same);
      expect(a, isNot(differentInstallation));
      expect(a.hashCode, same.hashCode);
    });
  });

  group('BootstrapRequest V2 validation + canonical serialization', () {
    test('accepts the populated frozen fixture', () {
      expect(() => fixtureBootstrapRequest().validate(), returnsNormally);
    });

    test('canonical toJson emits exactly 11 keys with explicit null optionals',
        () {
      final BootstrapRequest request =
          fixtureBootstrapRequest(populatedOptionals: false);
      request.validate();
      expect(
        request.toJson(),
        <String, Object?>{
          'app_id': request.appId,
          'installation_id': request.installationId,
          'platform': request.platform.name,
          'app_version': null,
          'build_number': null,
          'os_version': null,
          'locale': null,
          'region': null,
          'public_key': request.publicKey,
          'attestation': null,
          'bootstrap_request_id': request.bootstrapRequestId,
        },
      );
    });

    test('required identity fields use 64 UTF-8 byte caps', () {
      final BootstrapRequest pass = fixtureBootstrapRequest(appId: 'é' * 32);
      expect(() => pass.validate(), returnsNormally); // 64 UTF-8 bytes.
      final BootstrapRequest fail = fixtureBootstrapRequest(appId: 'é' * 33);
      expect(() => fail.validate(), throwsArgumentError); // 66 bytes.
      expect(
        () => fixtureBootstrapRequest(installationId: '').validate(),
        throwsArgumentError,
      );
    });

    test('diagnostic/routing optionals reject empty and use field byte caps',
        () {
      final BootstrapRequest empty = BootstrapRequest(
        appId: 'app-a',
        installationId: 'inst-a',
        platform: NebulaPlatform.android,
        publicKey: fixtureP256PublicKey,
        bootstrapRequestId: 'req-a',
        appVersion: '',
        buildNumber: '',
        osVersion: '',
        locale: '',
        region: '',
        attestation: '',
      );
      expect(() => empty.validate(), throwsArgumentError);
      expect(
        () => fixtureBootstrapRequest(locale: '界' * 21).validate(),
        returnsNormally,
      ); // 63 bytes.
      expect(
        () => fixtureBootstrapRequest(locale: '界' * 22).validate(),
        throwsArgumentError,
      ); // 66 bytes.
      expect(
        () => fixtureBootstrapRequest(osVersion: 'é' * 65).validate(),
        throwsArgumentError,
      ); // 130 bytes.
    });

    test('attestation uses 16 KiB byte cap and canonical body uses 32 KiB cap',
        () {
      expect(
        () => fixtureBootstrapRequest(attestation: 'x' * 16384).validate(),
        returnsNormally,
      );
      expect(
        () => fixtureBootstrapRequest(attestation: 'x' * 16385).validate(),
        throwsArgumentError,
      );
      // Field bytes are legal, but JSON escaping doubles every quote and pushes
      // the canonical body over the Backend's 32 KiB BodyLimit.
      expect(
        () => fixtureBootstrapRequest(attestation: '"' * 16384).validate(),
        throwsArgumentError,
      );
    });

    test('public key must be valid base64url P-256 SPKI DER', () {
      expect(() => fixtureBootstrapRequest().validate(), returnsNormally);
      expect(
        () => fixtureBootstrapRequest(
          publicKey: '${fixtureP256PublicKey}==',
        ).validate(),
        returnsNormally,
      ); // Backend accepts padded base64url too.
      expect(
        () => fixtureBootstrapRequest(publicKey: 'not+base64/key').validate(),
        throwsArgumentError,
      );
      expect(
        () => fixtureBootstrapRequest(publicKey: 'x' * 1025).validate(),
        throwsArgumentError,
      );

      final List<int> der = base64Url.decode(
        base64Url.normalize(fixtureP256PublicKey),
      );
      der[der.length - 1] ^= 1; // corrupt the curve point, keep DER shape.
      final String corrupted = base64Url.encode(der).replaceAll('=', '');
      expect(
        () => fixtureBootstrapRequest(publicKey: corrupted).validate(),
        throwsArgumentError,
      );
    });
  });

  group('BootstrapResult.fromJson (docs/08 §4.2, real wire)', () {
    test('parses the full frozen response (unix seconds + ES256)', () {
      final r = BootstrapResult.fromJson(<String, Object?>{
        'installation_token': 'tok-1',
        'expires_at': 1785866400, // 2026-08-04T18:00:00Z
        'renew_after': 1785849120, // 2026-08-04T13:12:00Z (80% of 24h TTL)
        'server_time': 1785780000, // 2026-08-03T18:00:00Z
        'app_id': 'app-a',
        'installation_id': 'inst-1',
        'proof_algorithm': 'ES256',
        'attestation_state': 'limited',
        'minimum_supported_build': '20260701',
        'request_id': 'req-9',
      });
      expect(r.installationToken, 'tok-1');
      expect(r.proofAlgorithm, NebulaProofAlgorithm.es256);
      expect(r.attestationState, NebulaAttestationState.limited);
      expect(r.minimumSupportedBuild, '20260701');
      expect(r.appId, 'app-a');
      expect(r.expiresAt, DateTime.utc(2026, 8, 4, 18));
      expect(r.serverTime, DateTime.utc(2026, 8, 3, 18));
    });

    test('rejects non-integer wire time (must be unix seconds)', () {
      expect(
        () => BootstrapResult.fromJson(<String, Object?>{
          'installation_token': 'tok',
          'expires_at': '2026-08-04T18:00:00Z', // wrong wire type
          'renew_after': 1785849120,
          'server_time': 1785780000,
          'app_id': 'app-a',
          'installation_id': 'inst-1',
          'proof_algorithm': 'ES256',
          'attestation_state': 'not_supported',
          'request_id': 'req-9',
        }),
        throwsFormatException,
      );
    });

    test('rejects fractional unix seconds without truncation', () {
      Map<String, Object?> validWire() => <String, Object?>{
            'installation_token': 'tok',
            'expires_at': 1785866400,
            'renew_after': 1785849120,
            'server_time': 1785780000,
            'app_id': 'app-a',
            'installation_id': 'inst-1',
            'proof_algorithm': 'ES256',
            'attestation_state': 'not_supported',
            'request_id': 'req-9',
          };

      for (final MapEntry<String, double> invalid in <String, double>{
        'expires_at': 1.75,
        'renew_after': 1.25,
        'server_time': 1.5,
      }.entries) {
        final Map<String, Object?> wire = validWire()
          ..[invalid.key] = invalid.value;
        expect(
          () => BootstrapResult.fromJson(wire),
          throwsFormatException,
          reason: '${invalid.key} must be strict int64 wire',
        );
      }
    });

    test('minimum_supported_build is optional', () {
      final r = BootstrapResult.fromJson(<String, Object?>{
        'installation_token': 'tok-1',
        'expires_at': 1785866400,
        'renew_after': 1785849120,
        'server_time': 1785780000,
        'app_id': 'app-a',
        'installation_id': 'inst-1',
        'proof_algorithm': 'ES256',
        'attestation_state': 'not_supported',
        'request_id': 'req-9',
      });
      expect(r.minimumSupportedBuild, isNull);
    });
  });
}
