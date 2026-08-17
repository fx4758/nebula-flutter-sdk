import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('public barrel constructs SDK-owned Mobile Observability composition',
      () {
    final NebulaMobileObservability observability =
        NebulaMobileObservability.create(
      options: NebulaOptions(
        appId: 'app-public',
        baseUri: Uri.parse('https://example.invalid'),
        environment: NebulaEnvironment.staging,
      ),
      transport: FakeTransport(),
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      recoverInstallationTrust: () async => true,
      persistentStorage: InMemoryCacheStorage(),
    );

    expect(observability.analytics, isA<NebulaAnalytics>());
    expect(observability.errorReporting, isA<NebulaErrorReporting>());
  });
}
