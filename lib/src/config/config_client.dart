/// Effective config client (F2-01, docs/12 §12).
///
/// Implements the client cache semantics of docs/12 §6:
///  * TTL fresh window — serve cache without network within `ttl_seconds`;
///  * ETag/304 revalidation — sends `If-None-Match`, a 304 refreshes the
///    cached snapshot's freshness;
///  * single-flight — concurrent [getEffectiveConfig] share one fetch;
///  * stale-if-error — on a network/5xx/12004 failure, serve the cached
///    snapshot within `ttl + stale_if_error` when nothing security-critical
///    is involved;
///  * security-critical no-stale — `forced_upgrade` / `security_critical`
///    features are never served stale (§6.5);
///  * kill switch — a 12004 response is surfaced as a classified error and
///    the disabled state is never cached (§6.7).
///
/// Persistence is optional: when a [CacheStorage] is injected (F1-03), the
/// snapshot survives restarts so the app can start offline within the stale
/// window (F2 exit: 离线启动).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../auth/proof.dart';
import '../foundation/error_classification.dart';
import '../foundation/errors.dart';
import '../foundation/logging.dart';
import '../foundation/options.dart';
import '../storage/cache_storage.dart';
import '../storage/storage_namespace.dart';
import '../transport.dart';
import '../transport/cancellation_token.dart';
import '../transport/proof_headers.dart';
import 'config_endpoints.dart';
import 'effective_config.dart';
import 'nebula_config.dart';

/// 持久化缓存键（namespace 内）。
const String kRuntimeConfigCacheKey = 'runtime_config';

final class NebulaConfigClient implements NebulaConfig {
  NebulaConfigClient({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    this.endpoints = const ConfigEndpoints(),
    this.cacheStorage,
    this.logger,
    this.appBuild,
  })  : _options = options,
        _transport = transport,
        _proofSigner = proofSigner,
        _installationToken = installationToken,
        _namespace =
            StorageNamespace.app(options.environment, options.appId).toString();

  final NebulaOptions _options;
  final NebulaTransport _transport;
  final RequestProofSigner _proofSigner;
  final Future<String> Function() _installationToken;
  final ConfigEndpoints endpoints;

  /// 可选持久化缓存（F1-03）；不注入则仅内存缓存。
  final CacheStorage? cacheStorage;
  final NebulaLogger? logger;

  /// 客户端构建号：随请求 `X-App-Build` 上报，供服务端计算版本策略
  /// （docs/12 §3/§5）。
  final int? appBuild;

  final String _namespace;

  NebulaEffectiveConfig? _snapshot;
  DateTime? _receivedAt;
  Future<NebulaEffectiveConfig>? _inflight;

  @override
  String? get revision => _snapshot?.revision;

  @override
  Future<NebulaEffectiveConfig> getEffectiveConfig({
    NebulaCancellationToken? cancellationToken,
  }) async {
    final NebulaEffectiveConfig? cached = _snapshot ?? await _readPersisted();
    if (cached != null) {
      _snapshot = cached;
      if (_isFresh(cached)) return cached;
    }

    final Future<NebulaEffectiveConfig>? inflight = _inflight;
    if (inflight != null) return inflight;
    final Future<NebulaEffectiveConfig> future = _load();
    _inflight = future;
    try {
      return await future;
    } finally {
      _inflight = null;
    }
  }

  // --- internals -----------------------------------------------------------

  Future<NebulaEffectiveConfig> _load() async {
    final NebulaEffectiveConfig? cached = _snapshot;
    try {
      final NebulaEffectiveConfig? result = await _fetchOrRevalidate();
      if (result != null) return result;
      throw const NebulaHttpException(
        'runtime-config revalidation without any cache',
      );
    } on NebulaException catch (e) {
      if (cached != null && _canServeStale(cached, e)) {
        _log(cached, NebulaErrorCategory.temporarilyUnavailable,
            'serving stale (${e.runtimeType})');
        return cached;
      }
      rethrow;
    }
  }

  /// Fetches once; on HTTP 304 revalidates the cached snapshot (returns it).
  Future<NebulaEffectiveConfig?> _fetchOrRevalidate() async {
    final String? etag = _snapshot?.revision;
    try {
      final NebulaResponse resp = await _send(etag);
      final Object? data = resp.data;
      if (data is! Map<String, Object?>) {
        throw NebulaHttpException('runtime-config data is not an object');
      }
      final NebulaEffectiveConfig cfg = NebulaEffectiveConfig.fromJson(data);
      final DateTime receivedAt = DateTime.now().toUtc();
      _snapshot = cfg;
      _receivedAt = receivedAt;
      await _persist(cfg, data, receivedAt);
      _log(cfg, NebulaErrorCategory.success, null);
      return cfg;
    } on NebulaHttpException catch (e) {
      if (e.statusCode == 304) {
        // 条件命中：快照未变，续期（docs/12 §6.6）。
        if (_snapshot != null) _receivedAt = DateTime.now().toUtc();
        return _snapshot;
      }
      rethrow;
    }
  }

  Future<NebulaResponse> _send(String? etag) async {
    final String resolvedPath = _resolvePath(endpoints.runtimeConfig);
    final Map<String, String> headers = await buildAuthHeaders(
      method: NebulaHttpMethod.get,
      resolvedPath: resolvedPath,
      body: null,
      installationToken: await _installationToken(),
      signer: _proofSigner,
    );
    if (appBuild != null) {
      headers['X-App-Build'] = '$appBuild';
    }
    if (etag != null) {
      headers['If-None-Match'] = '"$etag"';
    }
    return _transport.send(NebulaRequest(
      method: NebulaHttpMethod.get,
      path: endpoints.runtimeConfig,
      headers: headers,
    ));
  }

  bool _isFresh(NebulaEffectiveConfig cfg) {
    final DateTime? received = _receivedAt;
    if (received == null) return false;
    final int ttl = cfg.cachePolicy.ttlSeconds;
    return DateTime.now().toUtc().difference(received) <
        Duration(seconds: ttl);
  }

  /// 是否允许 stale 兜底（docs/12 §6.3/§6.5/§6.7）：
  /// 仅网络类失败且快照在 stale 窗口内且不含安全关键内容。
  bool _canServeStale(NebulaEffectiveConfig cfg, NebulaException e) {
    if (e is NebulaCancelledException) return false;
    if (e is NebulaApiException) {
      if (e.code != 12004) return false; // 业务性错误不 stale（12001 等）
    }
    if (cfg.hasSecurityCritical) return false; // 安全关键绝不 stale
    final DateTime? received = _receivedAt;
    if (received == null) return false;
    final int staleWindow = cfg.cachePolicy.ttlSeconds +
        cfg.cachePolicy.staleIfErrorSeconds;
    return DateTime.now().toUtc().difference(received) <
        Duration(seconds: staleWindow);
  }

  Future<NebulaEffectiveConfig?> _readPersisted() async {
    final CacheStorage? store = cacheStorage;
    if (store == null) return null;
    final Uint8List? raw =
        await store.read(namespace: _namespace, key: kRuntimeConfigCacheKey);
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(utf8.decode(raw));
      if (json is! Map<String, Object?>) return null;
      final Object? data = json['data'];
      final Object? receivedRaw = json['received_at'];
      if (data is! Map<String, Object?> || receivedRaw is! int) return null;
      final NebulaEffectiveConfig cfg = NebulaEffectiveConfig.fromJson(data);
      _receivedAt = DateTime.fromMillisecondsSinceEpoch(receivedRaw * 1000,
          isUtc: true);
      return cfg;
    } on Object {
      // 缓存损坏即视为无缓存，走网络；绝不因坏缓存崩溃。
      return null;
    }
  }

  Future<void> _persist(
    NebulaEffectiveConfig cfg,
    Map<String, Object?> data,
    DateTime receivedAt,
  ) async {
    final CacheStorage? store = cacheStorage;
    if (store == null) return;
    final String payload = jsonEncode(<String, Object?>{
      'revision': cfg.revision,
      'received_at': receivedAt.millisecondsSinceEpoch ~/ 1000,
      'data': data,
    });
    await store.write(
      namespace: _namespace,
      key: kRuntimeConfigCacheKey,
      value: Uint8List.fromList(utf8.encode(payload)),
    );
  }

  void _log(
    NebulaEffectiveConfig cfg,
    NebulaErrorCategory result,
    String? message,
  ) {
    if (logger == null) return;
    logger!.log(NebulaLogEvent(
      requestId: null,
      endpoint: 'GET ${endpoints.runtimeConfig}',
      result: result,
      duration: Duration.zero,
      message: message,
    ));
  }

  String _resolvePath(String endpointPath) {
    final String base = _options.baseUri.path;
    final String b = base.endsWith('/') && base.isNotEmpty
        ? base.substring(0, base.length - 1)
        : base;
    final String p = endpointPath.startsWith('/')
        ? endpointPath
        : '/$endpointPath';
    return '$b$p';
  }
}
