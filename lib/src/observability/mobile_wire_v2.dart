/// Opt-in compact, low-cardinality Mobile Observability V2 wire codec.
/// Unrecognized/personal events must fall back to the exact V1 format.
library;

import 'dart:convert';
import 'dart:io';
import '../analytics/event.dart';
import '../error_reporting/report.dart';

final RegExp _dimension = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,47}$');
final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_.$<>]{0,79}$');
final RegExp _frame = RegExp(r'^#[0-9]{1,3} [A-Za-z_][A-Za-z0-9_.$<>]{0,79}$');
final RegExp _reportId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final RegExp _version = RegExp(r'^(?:|[0-9][A-Za-z0-9._+-]{0,31})$');
final RegExp _build = RegExp(r'^(?:|[0-9]{1,16})$');

Map<String, Object?>? compactAnalyticsBatch(
  String id,
  List<NebulaAnalyticsEvent> events,
) {
  if (events.isEmpty || events.length > 50) return null;
  final rows = <List<Object>>[];
  for (final e in events) {
    if (e.identifiable) return null;
    final ts = e.timestamp.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (ts <= 0) return null;
    if (e.name == 'page_view' && e.properties.length == 1) {
      final page = e.properties['page'];
      if (page is! String || !_dimension.hasMatch(page)) return null;
      rows.add(<Object>['p', ts, page]);
    } else if (e.name == 'feature_outcome' && e.properties.length == 2) {
      final feature = e.properties['feature'];
      final result = e.properties['result'];
      if (feature is! String ||
          result is! String ||
          !_dimension.hasMatch(feature) ||
          !_dimension.hasMatch(result))
        return null;
      rows.add(<Object>['f', ts, feature, result]);
    } else {
      return null;
    }
  }
  return <String, Object?>{'v': 2, 'b': id, 'e': rows};
}

Map<String, Object?>? compactErrorReports(List<NebulaErrorReport> reports) {
  if (reports.isEmpty || reports.length > 10) return null;
  final rows = <List<Object>>[];
  for (final r in reports) {
    if (r.safeMessage != 'caught_error' ||
        r.requestId != null ||
        !_identifier.hasMatch(r.errorType) ||
        !_reportId.hasMatch(r.reportId))
      return null;
    // Explicit blank strings are different from absent optional fields in V1.
    // Do not silently change receipt hash across protocol fallback.
    if (r.reportedAppVersion == '' || r.reportedBuildNumber == '') return null;
    final stack = r.stack;
    if (stack != 'stack_unavailable') {
      final frames = stack.split('\n');
      if (frames.length > 8 || frames.any((f) => !_frame.hasMatch(f)))
        return null;
    }
    final version = r.reportedAppVersion ?? '';
    final build = r.reportedBuildNumber ?? '';
    if (!_version.hasMatch(version) ||
        !_build.hasMatch(build) ||
        stack.length > 640)
      return null;
    rows.add(<Object>[
      r.reportId,
      r.occurredAt.millisecondsSinceEpoch ~/ 1000,
      r.errorType,
      stack,
      version,
      build,
    ]);
  }
  return <String, Object?>{'v': 2, 'r': rows};
}

/// gzip only after 768 bytes and >=20% reduction; save CPU for small uploads.
List<int>? maybeCompressTelemetry(Map<String, Object?> body) {
  final source = utf8.encode(jsonEncode(body));
  if (source.length < 768 || source.length > 16 * 1024) return null;
  final compressed = ZLibEncoder(gzip: true, level: 1).convert(source);
  return compressed.length * 5 <= source.length * 4 ? compressed : null;
}
