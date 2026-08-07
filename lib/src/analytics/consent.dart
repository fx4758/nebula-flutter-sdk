/// Analytics consent (F2-03, docs/02 §4 privacy).
///
/// Fail-closed by default: analytics must not collect or persist identifiable
/// events before the user grants consent, and revoking consent purges unsent
/// privacy events. The concrete store (in-memory fake / CacheStorage-backed)
/// is a Port so the host can swap persistence.
library;

import 'dart:typed_data';

import '../foundation/options.dart';
import '../storage/cache_storage.dart';
import '../storage/storage_namespace.dart';

/// 用户对可识别事件收集的同意状态。
///
/// 默认 [revoked]（fail-closed）：宿主 App 必须在用户显式同意后才调用
/// [setConsent] 授予，否则 SDK 不收集可识别事件（docs/02 §4）。
enum NebulaConsent { granted, revoked }

/// 同意状态持久化 Port（docs/02 §4：同意选择需跨启动保持）。
abstract interface class NebulaConsentStore {
  Future<NebulaConsent> load();
  Future<void> save(NebulaConsent consent);
}

/// 内存 fake（测试/无持久化场景）。默认 revoked。
final class InMemoryConsentStore implements NebulaConsentStore {
  InMemoryConsentStore({NebulaConsent initial = NebulaConsent.revoked})
      : _consent = initial;

  NebulaConsent _consent;

  @override
  Future<NebulaConsent> load() async => _consent;

  @override
  Future<void> save(NebulaConsent consent) async {
    _consent = consent;
  }
}

/// CacheStorage 持久化实现（F1-03）：按 environment/App 命名空间隔离，
/// 值仅 `granted`/`revoked`，非敏感但需跨启动保留。
final class CacheConsentStore implements NebulaConsentStore {
  CacheConsentStore({
    required CacheStorage storage,
    required NebulaEnvironment environment,
    required String appId,
  })  : _storage = storage,
        _namespace = StorageNamespace.app(environment, appId).toString();

  static const String _key = 'analytics_consent';

  final CacheStorage _storage;
  final String _namespace;

  @override
  Future<NebulaConsent> load() async {
    final List<int>? raw =
        await _storage.read(namespace: _namespace, key: _key);
    if (raw == null) return NebulaConsent.revoked; // 缺省 fail-closed
    final String text = String.fromCharCodes(raw);
    return text == 'granted' ? NebulaConsent.granted : NebulaConsent.revoked;
  }

  @override
  Future<void> save(NebulaConsent consent) async {
    await _storage.write(
      namespace: _namespace,
      key: _key,
      value: Uint8List.fromList(
        (consent == NebulaConsent.granted ? 'granted' : 'revoked').codeUnits,
      ),
    );
  }
}
