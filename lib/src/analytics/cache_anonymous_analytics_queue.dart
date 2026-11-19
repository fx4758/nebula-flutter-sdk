/// Tiny, opt-in, anonymous-only durable analytics queue.
///
/// Unlike error reports, generic SDK analytics may contain identifying
/// properties. Only the narrow compact observability allowlist is eligible
/// here. No user or installation identifier is stored. The host supplies
/// its existing app-private CacheStorage implementation.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../foundation/options.dart';
import '../observability/mobile_wire_v2.dart';
import '../storage/cache_storage.dart';
import '../storage/storage_namespace.dart';
import 'event.dart';

final class CachedAnonymousAnalyticsRecord {
  const CachedAnonymousAnalyticsRecord(this.event, this.queuedAt);
  final NebulaAnalyticsEvent event;
  final DateTime queuedAt;
}

final class CachedAnonymousAnalyticsSnapshot {
  const CachedAnonymousAnalyticsSnapshot({
    required this.records,
    this.assignedBatchId,
    this.assignedCount = 0,
  });
  final List<CachedAnonymousAnalyticsRecord> records;
  final String? assignedBatchId;
  final int assignedCount;
}

final class CachedAnonymousAnalyticsQueue {
  CachedAnonymousAnalyticsQueue({
    required CacheStorage storage,
    required NebulaEnvironment environment,
    required String appId,
  }) : _storage = storage,
       _namespace = StorageNamespace.app(environment, appId).toString();

  static const _key = 'anonymous_analytics_queue_v1';
  static const _version = 1;
  static const int maxRecords = 48;
  static const int maxBytes = 16 * 1024;
  final CacheStorage _storage;
  final String _namespace;

  static bool allows(NebulaAnalyticsEvent event) =>
      compactAnalyticsBatch('local', <NebulaAnalyticsEvent>[event]) != null;

  Future<CachedAnonymousAnalyticsSnapshot> load() async {
    try {
      final Uint8List? bytes = await _storage.read(
        namespace: _namespace,
        key: _key,
      );
      if (bytes == null) {
        return const CachedAnonymousAnalyticsSnapshot(records: []);
      }
      if (bytes.length > maxBytes) throw const FormatException('oversize');
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> || decoded['v'] != _version) {
        throw const FormatException('invalid version');
      }
      final Object? rawRows = decoded['rows'];
      if (rawRows is! List || rawRows.length > maxRecords) {
        throw const FormatException('invalid rows');
      }
      final rows = <CachedAnonymousAnalyticsRecord>[];
      for (final Object? raw in rawRows) {
        if (raw is! List ||
            raw.length != 5 ||
            raw[0] is! String ||
            raw[1] is! int ||
            raw[2] is! int ||
            raw[3] is! String ||
            raw[4] is! String) {
          throw const FormatException('invalid entry');
        }
        final String kind = raw[0] as String;
        final int occurredMs = raw[1] as int;
        final int queuedMs = raw[2] as int;
        final String first = raw[3] as String;
        final String second = raw[4] as String;
        if (occurredMs <= 0 || queuedMs <= 0) {
          throw const FormatException('invalid time');
        }
        final NebulaAnalyticsEvent event;
        if (kind == 'p' && second.isEmpty) {
          event = NebulaAnalyticsEvent(
            name: 'page_view',
            privacy: NebulaEventPrivacy.anonymous,
            properties: {'page': first},
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              occurredMs,
              isUtc: true,
            ),
          );
        } else if (kind == 'f') {
          event = NebulaAnalyticsEvent(
            name: 'feature_outcome',
            privacy: NebulaEventPrivacy.anonymous,
            properties: {'feature': first, 'result': second},
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              occurredMs,
              isUtc: true,
            ),
          );
        } else {
          throw const FormatException('invalid kind');
        }
        if (!allows(event)) throw const FormatException('unsafe dimension');
        rows.add(
          CachedAnonymousAnalyticsRecord(
            event,
            DateTime.fromMillisecondsSinceEpoch(queuedMs, isUtc: true),
          ),
        );
      }
      final Object? rawId = decoded['batch'];
      final Object? rawCount = decoded['count'];
      if (rawId != null &&
          (rawId is! String ||
              rawId.isEmpty ||
              rawId.length > 128 ||
              rawCount is! int ||
              rawCount <= 0 ||
              rawCount > rows.length)) {
        throw const FormatException('invalid assigned batch');
      }
      if (rawId == null && rawCount != null) {
        throw const FormatException('orphan assigned count');
      }
      return CachedAnonymousAnalyticsSnapshot(
        records: rows,
        assignedBatchId: rawId as String?,
        assignedCount: rawCount is int ? rawCount : 0,
      );
    } on Object {
      // Corrupted cache is discarded; no exceptions may escape into NFC flows.
      try {
        await _storage.delete(namespace: _namespace, key: _key);
      } on Object {
        /* best effort */
      }
      return const CachedAnonymousAnalyticsSnapshot(records: []);
    }
  }

  Future<void> save(CachedAnonymousAnalyticsSnapshot snapshot) async {
    final rows = snapshot.records;
    if (rows.length > maxRecords || rows.any((r) => !allows(r.event))) {
      throw const FormatException('unsafe or oversized analytics queue');
    }
    if (rows.isEmpty) {
      await _storage.delete(namespace: _namespace, key: _key);
      return;
    }
    final data = <String, Object?>{
      'v': _version,
      'rows': [for (final record in rows) _encodeRecord(record)],
      if (snapshot.assignedBatchId != null) 'batch': snapshot.assignedBatchId,
      if (snapshot.assignedBatchId != null) 'count': snapshot.assignedCount,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    if (bytes.length > maxBytes) throw const FormatException('queue > 16 KiB');
    await _storage.write(
      namespace: _namespace,
      key: _key,
      value: bytes,
      ttl: const Duration(hours: 24),
    );
  }

  static List<Object> _encodeRecord(CachedAnonymousAnalyticsRecord r) {
    final e = r.event;
    final p = e.properties;
    return <Object>[
      e.name == 'page_view' ? 'p' : 'f',
      e.timestamp.toUtc().millisecondsSinceEpoch,
      r.queuedAt.toUtc().millisecondsSinceEpoch,
      (e.name == 'page_view' ? p['page'] : p['feature']) as String,
      e.name == 'page_view' ? '' : p['result'] as String,
    ];
  }
}
