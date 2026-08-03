import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('FakeInstallationKeyPort (FS-01 key Port contract)', () {
    test('generateKeyPair returns public side + private ref, never private key',
        () async {
      final port = FakeInstallationKeyPort();
      final pair = await port.generateKeyPair();
      expect(pair.publicKeyDer, isNotEmpty);
      expect(pair.publicKeyThumbprint, isNotEmpty);
      expect(pair.privateKeyRef, isNotEmpty);
      // Public contract: no private key material field exists on the type.
      expect(pair.toString(), isNot(contains('private key')));
    });

    test('each generate produces a distinct identity (reinstall = new key)',
        () async {
      final port = FakeInstallationKeyPort();
      final a = await port.generateKeyPair();
      final b = await port.generateKeyPair();
      expect(a.privateKeyRef, isNot(b.privateKeyRef));
      expect(a.publicKeyThumbprint, isNot(b.publicKeyThumbprint));
    });

    test('sign records the exact message (deterministic pipeline input)',
        () async {
      final port = FakeInstallationKeyPort();
      final pair = await port.generateKeyPair();
      final sig =
          await port.sign(keyRef: pair.privateKeyRef, message: 'V1\nPOST');
      expect(port.signedMessages, ['V1\nPOST']);
      expect(sig, isNotEmpty);
    });
  });
}
