import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

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

  group('BootstrapRequest.validate (docs/08 §4.1 limits)', () {
    BootstrapRequest valid() => const BootstrapRequest(
          appId: 'app-a',
          installationId: 'inst-1',
          platform: NebulaPlatform.android,
          publicKey: 'public-key-der',
          bootstrapRequestId: 'req-1',
        );

    test('accepts a fully valid request', () {
      expect(() => valid().validate(), returnsNormally);
    });

    test('rejects empty appId', () {
      final r = valid();
      expect(
        () => BootstrapRequest(
          appId: '',
          installationId: r.installationId,
          platform: r.platform,
          publicKey: r.publicKey,
          bootstrapRequestId: r.bootstrapRequestId,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects string fields over 128 chars', () {
      final r = valid();
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: 'x' * 129,
          platform: r.platform,
          publicKey: r.publicKey,
          bootstrapRequestId: r.bootstrapRequestId,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: r.installationId,
          platform: r.platform,
          publicKey: r.publicKey,
          bootstrapRequestId: r.bootstrapRequestId,
          osVersion: 'x' * 129,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('attestation cap is 16 KiB, not 128 chars (provider evidence)', () {
      final r = valid();
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: r.installationId,
          platform: r.platform,
          publicKey: r.publicKey,
          bootstrapRequestId: r.bootstrapRequestId,
          attestation: 'x' * 16000, // < 16 KiB
        ).validate(),
        returnsNormally,
      );
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: r.installationId,
          platform: r.platform,
          publicKey: r.publicKey,
          bootstrapRequestId: r.bootstrapRequestId,
          attestation: 'x' * 16385, // > 16 KiB
        ).validate(),
        throwsArgumentError,
      );
    });

    test('publicKey allows ES256 DER well under the cap and rejects empty', () {
      final r = valid();
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: r.installationId,
          platform: r.platform,
          publicKey: 'x' * 2048,
          bootstrapRequestId: r.bootstrapRequestId,
        ).validate(),
        returnsNormally,
      );
      expect(
        () => BootstrapRequest(
          appId: r.appId,
          installationId: r.installationId,
          platform: r.platform,
          publicKey: '',
          bootstrapRequestId: r.bootstrapRequestId,
        ).validate(),
        throwsArgumentError,
      );
    });
  });

  group('BootstrapResult.fromJson (docs/08 §4.2 frozen fields)', () {
    test('parses the full frozen response', () {
      final r = BootstrapResult.fromJson(<String, Object?>{
        'installation_token': 'tok-1',
        'expires_at': '2026-08-04T18:00:00Z',
        'renew_after': '2026-08-03T19:00:00Z',
        'server_time': '2026-08-03T18:00:00Z',
        'app_id': 'app-a',
        'installation_id': 'inst-1',
        'proof_algorithm': 'es256',
        'attestation_state': 'limited',
        'minimum_supported_build': '20260701',
        'request_id': 'req-9',
      });
      expect(r.installationToken, 'tok-1');
      expect(r.proofAlgorithm, NebulaProofAlgorithm.es256);
      expect(r.attestationState, NebulaAttestationState.limited);
      expect(r.minimumSupportedBuild, '20260701');
      expect(r.appId, 'app-a');
    });

    test('minimum_supported_build is optional', () {
      final r = BootstrapResult.fromJson(<String, Object?>{
        'installation_token': 'tok-1',
        'expires_at': '2026-08-04T18:00:00Z',
        'renew_after': '2026-08-03T19:00:00Z',
        'server_time': '2026-08-03T18:00:00Z',
        'app_id': 'app-a',
        'installation_id': 'inst-1',
        'proof_algorithm': 'es256',
        'attestation_state': 'not_supported',
        'request_id': 'req-9',
      });
      expect(r.minimumSupportedBuild, isNull);
    });
  });
}
