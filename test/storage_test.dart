import 'dart:typed_data';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('StorageNamespace (docs/02 §2 environment/app_id/user_id/key)', () {
    test('app scope omits the user segment', () {
      expect(
        StorageNamespace.app(NebulaEnvironment.staging, 'com.example.a')
            .toString(),
        'staging/com.example.a',
      );
      expect(
        StorageNamespace.app(NebulaEnvironment.production, 'com.example.a')
            .toString(),
        'production/com.example.a',
      );
    });

    test('user scope appends the user segment', () {
      expect(
        StorageNamespace.user(
          NebulaEnvironment.staging,
          'com.example.a',
          'u1',
        ).toString(),
        'staging/com.example.a/u1',
      );
    });

    test('key() appends the trailing relative key', () {
      expect(
        StorageNamespace.app(NebulaEnvironment.production, 'app')
            .key('refresh_token'),
        'production/app/refresh_token',
      );
      expect(
        StorageNamespace.user(NebulaEnvironment.production, 'app', 'u1')
            .key('refresh_token'),
        'production/app/u1/refresh_token',
      );
    });

    test('different App / env / user produce distinct namespaces', () {
      const env = NebulaEnvironment.staging;
      final a = StorageNamespace.app(env, 'com.example.a');
      final b = StorageNamespace.app(env, 'com.example.b');
      final prod = StorageNamespace.app(NebulaEnvironment.production, 'com.example.a');
      final u1 = StorageNamespace.user(env, 'com.example.a', 'u1');
      final u2 = StorageNamespace.user(env, 'com.example.a', 'u2');

      expect(a.toString(), isNot(equals(b.toString())));
      expect(a.toString(), isNot(equals(prod.toString())));
      expect(a.toString(), isNot(equals(u1.toString())));
      expect(u1.toString(), isNot(equals(u2.toString())));
    });

    test('segments reject empty / slash / NUL to protect scoping', () {
      expect(
        () => StorageNamespace.app(NebulaEnvironment.staging, ''),
        throwsArgumentError,
      );
      expect(
        () => StorageNamespace.app(NebulaEnvironment.staging, 'a/b'),
        throwsArgumentError,
      );
      expect(
        () => StorageNamespace.user(NebulaEnvironment.staging, 'app', 'u/1'),
        throwsArgumentError,
      );
      expect(
        () => StorageNamespace.user(NebulaEnvironment.staging, 'app', '\x00'),
        throwsArgumentError,
      );
      expect(
        () => StorageNamespace.app(NebulaEnvironment.staging, 'app').key('a/b'),
        throwsArgumentError,
      );
    });
  });

  group('InMemorySecureStorage (F1-03 secure storage Port)', () {
    test('write/read/delete round-trip within one namespace', () async {
      final store = InMemorySecureStorage();
      const ns = 'staging/com.example.a';
      await store.write(namespace: ns, key: 'refresh_token', value: 'tok-1');
      expect(
        await store.read(namespace: ns, key: 'refresh_token'),
        'tok-1',
      );
      await store.delete(namespace: ns, key: 'refresh_token');
      expect(
        await store.read(namespace: ns, key: 'refresh_token'),
        isNull,
      );
    });

    test('namespaces are isolated: no cross-env/App/user leakage', () async {
      final store = InMemorySecureStorage();
      const nsA = 'staging/com.example.a';
      const nsB = 'production/com.example.a';
      const nsC = 'staging/com.example.b';
      const nsU = 'staging/com.example.a/u1';

      await store.write(namespace: nsA, key: 'refresh_token', value: 'secret-a');
      expect(await store.read(namespace: nsB, key: 'refresh_token'), isNull);
      expect(await store.read(namespace: nsC, key: 'refresh_token'), isNull);
      expect(await store.read(namespace: nsU, key: 'refresh_token'), isNull);
      expect(
        await store.read(namespace: nsA, key: 'refresh_token'),
        'secret-a',
      );
    });

    test('clearNamespace wipes only that namespace', () async {
      final store = InMemorySecureStorage();
      const nsA = 'staging/com.example.a';
      const nsB = 'staging/com.example.b';
      await store.write(namespace: nsA, key: 'refresh_token', value: 'x');
      await store.write(namespace: nsB, key: 'refresh_token', value: 'y');

      await store.clearNamespace(nsA);
      expect(await store.read(namespace: nsA, key: 'refresh_token'), isNull);
      expect(await store.read(namespace: nsB, key: 'refresh_token'), 'y');
    });
  });

  group('InMemoryCacheStorage (F1-03 cache storage Port)', () {
    Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

    test('write/read/delete round-trip of bytes', () async {
      final store = InMemoryCacheStorage();
      const ns = 'staging/com.example.a';
      await store.write(namespace: ns, key: 'config', value: bytes('hello'));
      expect(
        await store.read(namespace: ns, key: 'config'),
        bytes('hello'),
      );
      await store.delete(namespace: ns, key: 'config');
      expect(await store.read(namespace: ns, key: 'config'), isNull);
    });

    test('namespaces are isolated', () async {
      final store = InMemoryCacheStorage();
      const nsA = 'staging/com.example.a';
      const nsB = 'staging/com.example.b';
      await store.write(namespace: nsA, key: 'config', value: bytes('a'));
      expect(await store.read(namespace: nsB, key: 'config'), isNull);
      expect(await store.read(namespace: nsA, key: 'config'), bytes('a'));
    });

    test('clearNamespace wipes only that namespace', () async {
      final store = InMemoryCacheStorage();
      const nsA = 'staging/com.example.a';
      const nsB = 'staging/com.example.b';
      await store.write(namespace: nsA, key: 'config', value: bytes('x'));
      await store.write(namespace: nsB, key: 'config', value: bytes('y'));
      await store.clearNamespace(nsA);
      expect(await store.read(namespace: nsA, key: 'config'), isNull);
      expect(await store.read(namespace: nsB, key: 'config'), bytes('y'));
    });

    test('ttl hint expires the entry on read', () async {
      final store = InMemoryCacheStorage();
      const ns = 'staging/com.example.a';
      await store.write(
        namespace: ns,
        key: 'config',
        value: bytes('tmp'),
        ttl: const Duration(milliseconds: 100),
      );
      expect(await store.read(namespace: ns, key: 'config'), bytes('tmp'));
      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(await store.read(namespace: ns, key: 'config'), isNull);
    });

    test('write without ttl persists across reads', () async {
      final store = InMemoryCacheStorage();
      const ns = 'staging/com.example.a';
      await store.write(namespace: ns, key: 'config', value: bytes('keep'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await store.read(namespace: ns, key: 'config'), bytes('keep'));
    });
  });

  group('multi-App isolation (docs/04 multi-App test matrix)', () {
    test('App A data is unreadable under App B namespace', () async {
      final secure = InMemorySecureStorage();
      final cache = InMemoryCacheStorage();
      const nsA = 'staging/com.example.a';
      const nsB = 'staging/com.example.b';

      await secure.write(namespace: nsA, key: 'refresh_token', value: 'rA');
      expect(await secure.read(namespace: nsB, key: 'refresh_token'), isNull);

      await cache.write(
        namespace: nsA,
        key: 'config',
        value: Uint8List.fromList('cfgA'.codeUnits),
      );
      expect(await cache.read(namespace: nsB, key: 'config'), isNull);
    });
  });
}
