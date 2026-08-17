library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../foundation/options.dart';
import '../storage/cache_storage.dart';
import '../storage/storage_namespace.dart';
import 'budget.dart';
import 'report.dart';
import 'store.dart';

final class CacheErrorReportStore implements ErrorReportStore {
  CacheErrorReportStore({
    required CacheStorage storage,
    required NebulaEnvironment environment,
    required String appId,
  })  : _storage = storage,
        _namespace = StorageNamespace.app(environment, appId).toString();

  static const int _version = 1;
  static const String _key = 'error_reporting_queue_v1';
  final CacheStorage _storage;
  final String _namespace;
  Future<void> _tail = Future<void>.value();

  @override
  Future<ErrorStoreSaveResult> saveBounded(
    NebulaErrorReport report, {
    required ErrorReportingBudget budget,
    required DateTime now,
  }) =>
      _serialized(() async {
        budget.validate();
        final DateTime utcNow = now.toUtc();
        final _LoadedQueue loaded = await _load();
        final List<StoredErrorReport> records = loaded.records;
        final int expired = _expire(records, budget, utcNow);
        final int reportBytes = report.estimatedBytes;
        if (reportBytes > budget.maxStoredBytes) {
          if (expired > 0 || loaded.recoveredFromCorruption) {
            await _persist(records);
          }
          return ErrorStoreSaveResult(
            persisted: false,
            expiredCount: expired,
          );
        }
        records.removeWhere(
          (StoredErrorReport stored) =>
              stored.report.reportId == report.reportId,
        );
        int evicted = 0;
        while (records.isNotEmpty &&
            (records.length >= budget.maxStoredReports ||
                _bytes(records) + reportBytes > budget.maxStoredBytes)) {
          records.removeAt(0);
          evicted++;
        }
        records.add(StoredErrorReport(report: report, storedAt: utcNow));
        await _persist(records);
        return ErrorStoreSaveResult(
          persisted: true,
          evictedCount: evicted,
          expiredCount: expired,
        );
      });

  @override
  Future<ErrorStoreReadResult> readReady({
    required ErrorReportingBudget budget,
    required DateTime now,
  }) =>
      _serialized(() async {
        budget.validate();
        final DateTime utcNow = now.toUtc();
        final _LoadedQueue loaded = await _load();
        final List<StoredErrorReport> records = loaded.records;
        final int expired = _expire(records, budget, utcNow);
        if (expired > 0 || loaded.recoveredFromCorruption) {
          await _persist(records);
        }
        final List<StoredErrorReport> ready = <StoredErrorReport>[];
        int bytes = 0;
        for (final StoredErrorReport stored in records) {
          if (stored.attemptCount >= budget.maxAttempts) continue;
          if (stored.nextAttemptAt?.isAfter(utcNow) ?? false) continue;
          final int reportBytes = stored.report.estimatedBytes;
          if (ready.length >= budget.maxReportsPerFlush ||
              bytes + reportBytes > budget.maxBytesPerFlush) {
            break;
          }
          ready.add(stored);
          bytes += reportBytes;
        }
        return ErrorStoreReadResult(
          reports: List<StoredErrorReport>.unmodifiable(ready),
          expiredCount: expired,
        );
      });

  @override
  Future<void> deleteById(Iterable<String> reportIds) => _serialized(() async {
        final Set<String> ids = reportIds.toSet();
        if (ids.isEmpty) return;
        final _LoadedQueue loaded = await _load();
        final List<StoredErrorReport> records = loaded.records;
        final int before = records.length;
        records.removeWhere(
          (StoredErrorReport stored) => ids.contains(stored.report.reportId),
        );
        if (records.length != before || loaded.recoveredFromCorruption) {
          await _persist(records);
        }
      });

  @override
  Future<void> scheduleRetry(
    Iterable<String> reportIds, {
    required int attemptCount,
    required DateTime nextAttemptAt,
  }) =>
      _serialized(() async {
        final Set<String> ids = reportIds.toSet();
        if (ids.isEmpty) return;
        final _LoadedQueue loaded = await _load();
        final List<StoredErrorReport> records = loaded.records;
        bool changed = false;
        for (int i = 0; i < records.length; i++) {
          final StoredErrorReport stored = records[i];
          if (!ids.contains(stored.report.reportId)) continue;
          records[i] = StoredErrorReport(
            report: stored.report,
            storedAt: stored.storedAt,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt.toUtc(),
          );
          changed = true;
        }
        if (changed || loaded.recoveredFromCorruption) {
          await _persist(records);
        }
      });

  Future<_LoadedQueue> _load() async {
    final Uint8List? bytes =
        await _storage.read(namespace: _namespace, key: _key);
    if (bytes == null) return _LoadedQueue(<StoredErrorReport>[]);
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> || decoded['version'] != _version) {
        throw const FormatException('unsupported Error Reporting queue');
      }
      final Object? rawRecords = decoded['records'];
      if (rawRecords is! List) {
        throw const FormatException('invalid Error Reporting queue records');
      }
      final List<StoredErrorReport> records = <StoredErrorReport>[];
      for (final Object? raw in rawRecords) {
        records.add(_decodeRecord(raw));
      }
      records.sort(
        (StoredErrorReport a, StoredErrorReport b) =>
            a.storedAt.compareTo(b.storedAt),
      );
      return _LoadedQueue(records);
    } on Object {
      await _storage.delete(namespace: _namespace, key: _key);
      return _LoadedQueue(
        <StoredErrorReport>[],
        recoveredFromCorruption: true,
      );
    }
  }

  StoredErrorReport _decodeRecord(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('invalid Error Reporting queue record');
    }
    final String reportId = _requiredString(raw, 'report_id');
    final int occurredAt = _requiredInt(raw, 'occurred_at');
    final String errorType = _requiredString(raw, 'error_type');
    final String safeMessage =
        _requiredString(raw, 'safe_message', allowEmpty: true);
    final String stack = _requiredString(raw, 'stack', allowEmpty: true);
    final int storedAt = _requiredInt(raw, 'stored_at_ms');
    final int encodedBytes = _requiredInt(raw, 'encoded_bytes');
    final int attemptCount = _requiredInt(raw, 'attempt_count');
    final Object? nextAttemptRaw = raw['next_attempt_at_ms'];
    if (attemptCount < 0 || encodedBytes < 0) {
      throw const FormatException('invalid Error Reporting delivery metadata');
    }
    if (nextAttemptRaw != null && nextAttemptRaw is! int) {
      throw const FormatException('invalid next attempt timestamp');
    }
    final NebulaErrorReport report = NebulaErrorReport(
      reportId: reportId,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        occurredAt * 1000,
        isUtc: true,
      ),
      errorType: errorType,
      safeMessage: safeMessage,
      stack: stack,
      requestId: _optionalString(raw, 'request_id'),
      reportedAppVersion: _optionalString(raw, 'reported_app_version'),
      reportedBuildNumber: _optionalString(raw, 'reported_build_number'),
    );
    if (report.estimatedBytes != encodedBytes) {
      throw const FormatException('Error Reporting encoded byte mismatch');
    }
    return StoredErrorReport(
      report: report,
      storedAt: DateTime.fromMillisecondsSinceEpoch(storedAt, isUtc: true),
      attemptCount: attemptCount,
      nextAttemptAt: nextAttemptRaw == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextAttemptRaw as int,
              isUtc: true),
    );
  }

  Future<void> _persist(List<StoredErrorReport> records) async {
    if (records.isEmpty) {
      await _storage.delete(namespace: _namespace, key: _key);
      return;
    }
    final Map<String, Object?> envelope = <String, Object?>{
      'version': _version,
      'records': records.map(_encodeRecord).toList(growable: false),
    };
    await _storage.write(
      namespace: _namespace,
      key: _key,
      value: Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
    );
  }

  Map<String, Object?> _encodeRecord(StoredErrorReport stored) =>
      <String, Object?>{
        ...stored.report.toDiagnosticMap(),
        'stored_at_ms': stored.storedAt.toUtc().millisecondsSinceEpoch,
        'encoded_bytes': stored.report.estimatedBytes,
        'attempt_count': stored.attemptCount,
        'next_attempt_at_ms':
            stored.nextAttemptAt?.toUtc().millisecondsSinceEpoch,
      };

  int _expire(
    List<StoredErrorReport> records,
    ErrorReportingBudget budget,
    DateTime now,
  ) {
    final int before = records.length;
    records.removeWhere(
      (StoredErrorReport stored) =>
          now.difference(stored.storedAt.toUtc()) > budget.maxReportAge,
    );
    return before - records.length;
  }

  int _bytes(List<StoredErrorReport> records) => records.fold<int>(
        0,
        (int total, StoredErrorReport stored) =>
            total + stored.report.estimatedBytes,
      );

  String _requiredString(
    Map<String, Object?> map,
    String key, {
    bool allowEmpty = false,
  }) {
    final Object? value = map[key];
    if (value is! String || (!allowEmpty && value.isEmpty)) {
      throw FormatException('invalid $key');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('invalid $key');
    return value;
  }

  int _requiredInt(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value is! int) throw FormatException('invalid $key');
    return value;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final class _LoadedQueue {
  _LoadedQueue(this.records, {this.recoveredFromCorruption = false});

  final List<StoredErrorReport> records;
  final bool recoveredFromCorruption;
}
