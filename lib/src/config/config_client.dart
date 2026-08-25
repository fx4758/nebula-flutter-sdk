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
import 'dart:math';
import 'dart:typed_data';

import '../foundation/error_classification.dart';
import '../foundation/errors.dart';
import '../foundation/logging.dart';
import '../foundation/options.dart';
import '../foundation/request_proof.dart';
import '../foundation/sha256.dart';
import '../storage/cache_storage.dart';
import '../storage/storage_namespace.dart';
import '../transport.dart';
import '../transport/cancellation_token.dart';
import '../transport/proof_headers.dart';
import 'config_endpoints.dart';
import 'effective_config.dart';
import 'nebula_config.dart';

/// 持久化缓存键前缀（namespace 内）。F2-R1：键派生加入 installation 身份、
/// build 与 schema version，避免跨安装/跨构建命中陈旧缓存。
const String kRuntimeConfigCacheKey = 'runtime_config';

/// 持久化缓存格式版本：升级格式须递增并使旧缓存失效。
const int kRuntimeConfigSchemaVersion = 1;

/// 客户端可接受的快照总字节上限（docs/12 §8.3 64 KiB；紧凑编码近似）。
const int kMaxSnapshotBytes = 64 * 1024;

/// 持久化缓存条目字节上限（docs/12 §8.3 缓存上限；超限不落盘，防存储放大）。
const int kMaxCacheBytes = 64 * 1024;

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
    this.maxRetries = 1,
    this.retryBaseDelay = const Duration(milliseconds: 250),
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

  /// 幂等 GET 的有界重试次数（docs/02 §3：配置/幂等 GET 最多 2 次尝试，
  /// 指数退避 + jitter）。仅在瞬时传输类失败（超时/连接/5xx）时重试；
  /// 限流(429/40002)、业务码、畸形响应、取消一律不重试。
  final int maxRetries;

  /// 重试退避基值：第 n 次重试等待 `base << (n-1)` + jitter。
  final Duration retryBaseDelay;

  final String _namespace;

  NebulaEffectiveConfig? _snapshot;
  DateTime? _receivedAt;
  Future<NebulaEffectiveConfig>? _inflight;

  @override
  String? get revision => _snapshot?.revision;

  /// 派生持久化缓存键（F2-R1，docs/12 §6）：installation 身份哈希 + build +
  /// schema version——重装/安装轮换或 App 升级后不会命中上一身份的 fresh 缓存。
  Future<String> _cacheKey() async {
    final String instHash =
        sha256Hex(utf8.encode(await _installationToken())).substring(0, 16);
    final String build = appBuild?.toString() ?? 'na';
    return '$kRuntimeConfigCacheKey/v$kRuntimeConfigSchemaVersion/'
        'i$instHash/b$build/snapshot';
  }

  @override
  Future<void> clearCache() async {
    _snapshot = null;
    _receivedAt = null;
    _inflight = null;
    final CacheStorage? store = cacheStorage;
    if (store != null) {
      await store.delete(namespace: _namespace, key: await _cacheKey());
    }
  }

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
    final Future<NebulaEffectiveConfig> future = _load(cancellationToken);
    _inflight = future;
    try {
      return await future;
    } finally {
      _inflight = null;
    }
  }

  // --- internals -----------------------------------------------------------

  Future<NebulaEffectiveConfig> _load(
    NebulaCancellationToken? cancellationToken,
  ) async {
    final NebulaEffectiveConfig? cached = _snapshot;
    try {
      final NebulaEffectiveConfig? result =
          await _fetchOrRevalidate(cancellationToken);
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

  /// Fetches once (with bounded idempotent retry); on HTTP 304 revalidates the
  /// cached snapshot (returns it). Retries only transient transport failures
  /// (docs/02 §3), never 429/40002/business codes/parse errors/cancellation.
  Future<NebulaEffectiveConfig?> _fetchOrRevalidate(
    NebulaCancellationToken? cancellationToken,
  ) async {
    int attempt = 0;
    while (true) {
      final String? etag = _snapshot?.revision;
      try {
        final NebulaResponse resp = await _send(etag, cancellationToken);
        final Object? data = resp.data;
        if (data is! Map<String, Object?>) {
          throw const NebulaConfigParseException(
            'runtime-config data is not an object',
          );
        }
        // 总响应字节上限（docs/12 §8.3 64 KiB，紧凑编码近似；F2-R1）。
        if (utf8.encode(jsonEncode(data)).length > kMaxSnapshotBytes) {
          throw const NebulaConfigParseException(
            'runtime-config snapshot exceeds 64 KiB',
          );
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
        if (attempt < maxRetries && _isRetryableHttp(e)) {
          attempt++;
          await _retryDelay(attempt);
          continue;
        }
        rethrow;
      } on NebulaTimeoutException {
        if (attempt < maxRetries) {
          attempt++;
          await _retryDelay(attempt);
          continue;
        }
        rethrow;
      }
    }
  }

  /// 仅在瞬时传输类失败时重试：连接层（statusCode 为 null）或 5xx。
  /// 429/4xx 不重试（尊重限流，docs/02 §3）；畸形响应/业务码/取消不重试。
  bool _isRetryableHttp(NebulaHttpException e) {
    final int? status = e.statusCode;
    if (status == null) return true;
    return status >= 500;
  }

  Future<void> _retryDelay(int attempt) {
    final int base = retryBaseDelay.inMilliseconds;
    final int exp = base * (1 << (attempt - 1));
    final int jitter = Random().nextInt(exp ~/ 4 + 1);
    return Future<void>.delayed(Duration(milliseconds: exp + jitter));
  }

  Future<NebulaResponse> _send(
    String? etag,
    NebulaCancellationToken? cancellationToken,
  ) async {
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
      cancellationToken: cancellationToken, // F2-R1：公开参数真正生效
    ));
  }

  bool _isFresh(NebulaEffectiveConfig cfg) {
    final DateTime? received = _receivedAt;
    if (received == null) return false;
    final int ttl = cfg.cachePolicy.ttlSeconds;
    return DateTime.now().toUtc().difference(received) < Duration(seconds: ttl);
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
    final int staleWindow =
        cfg.cachePolicy.ttlSeconds + cfg.cachePolicy.staleIfErrorSeconds;
    return DateTime.now().toUtc().difference(received) <
        Duration(seconds: staleWindow);
  }

  Future<NebulaEffectiveConfig?> _readPersisted() async {
    final CacheStorage? store = cacheStorage;
    if (store == null) return null;
    final Uint8List? raw =
        await store.read(namespace: _namespace, key: await _cacheKey());
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(utf8.decode(raw));
      if (json is! Map<String, Object?>) return null;
      // F2-R1：schema version 不匹配的旧格式一律视为无缓存。
      if (json['schema_version'] != kRuntimeConfigSchemaVersion) return null;
      final Object? data = json['data'];
      final Object? receivedRaw = json['received_at'];
      if (data is! Map<String, Object?> || receivedRaw is! int) return null;
      final NebulaEffectiveConfig cfg = NebulaEffectiveConfig.fromJson(data);
      _receivedAt =
          DateTime.fromMillisecondsSinceEpoch(receivedRaw * 1000, isUtc: true);
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
      'schema_version': kRuntimeConfigSchemaVersion,
      'revision': cfg.revision,
      'received_at': receivedAt.millisecondsSinceEpoch ~/ 1000,
      'data': data,
    });
    final Uint8List bytes = Uint8List.fromList(utf8.encode(payload));
    // F2-R1：缓存条目字节上限（docs/12 §8.3），超限不落盘防存储放大。
    if (bytes.length > kMaxCacheBytes) return;
    await store.write(
      namespace: _namespace,
      key: await _cacheKey(),
      value: bytes,
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
    final String p =
        endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    return '$b$p';
  }
}
