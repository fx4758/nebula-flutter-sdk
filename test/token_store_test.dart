import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('tokenNamespace (environment/App namespace rule)', () {
    test('separates environment and App', () {
      expect(
        tokenNamespace(NebulaEnvironment.staging, 'com.example.a'),
        'staging:com.example.a',
      );
      expect(
        tokenNamespace(NebulaEnvironment.production, 'com.example.a'),
        'production:com.example.a',
      );
      expect(
        tokenNamespace(NebulaEnvironment.staging, 'com.example.b'),
        'staging:com.example.b',
      );
    });
  });

  group('InMemoryTokenStore (FS-01 secure token store Port)', () {
    test('write/read/delete round-trip within one namespace', () async {
      final store = InMemoryTokenStore();
      const ns = 'staging:com.example.a';
      await store.write(
          namespace: ns, key: tokenKeyInstallation, value: 'tok-1');
      expect(
          await store.read(namespace: ns, key: tokenKeyInstallation), 'tok-1');

      await store.delete(namespace: ns, key: tokenKeyInstallation);
      expect(
          await store.read(namespace: ns, key: tokenKeyInstallation), isNull);
    });

    test('namespaces are isolated: no cross-env or cross-App leakage',
        () async {
      final store = InMemoryTokenStore();
      const nsA = 'staging:com.example.a';
      const nsB = 'production:com.example.a';
      const nsC = 'staging:com.example.b';

      await store.write(
          namespace: nsA, key: tokenKeyRefresh, value: 'secret-a');
      // 同 App 不同环境
      expect(await store.read(namespace: nsB, key: tokenKeyRefresh), isNull);
      // 同环境不同 App
      expect(await store.read(namespace: nsC, key: tokenKeyRefresh), isNull);
      // 源命名空间仍可读
      expect(
          await store.read(namespace: nsA, key: tokenKeyRefresh), 'secret-a');
    });

    test('clearNamespace wipes only that namespace', () async {
      final store = InMemoryTokenStore();
      const nsA = 'staging:com.example.a';
      const nsB = 'staging:com.example.b';
      await store.write(namespace: nsA, key: tokenKeyRefresh, value: 'x');
      await store.write(namespace: nsB, key: tokenKeyRefresh, value: 'y');

      await store.clearNamespace(nsA);
      expect(await store.read(namespace: nsA, key: tokenKeyRefresh), isNull);
      expect(await store.read(namespace: nsB, key: tokenKeyRefresh), 'y');
    });
  });
}
