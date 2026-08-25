import 'dart:convert';
import 'dart:io';

import 'api_surface.dart' as api_surface;
import 'product_erasure_guard.dart' as product_erasure;
import 'sdk_layer_graph_guard.dart' as layer_graph;
import 'secret_scan.dart' as secret_scan;

final class Finding {
  const Finding(this.ruleId, this.message);

  final String ruleId;
  final String message;

  @override
  String toString() => '[$ruleId] $message';
}

void main() {
  final Directory root = Directory.current;
  final File policyFile = File('${root.path}/governance/policy.json');
  if (!policyFile.existsSync()) {
    stderr.writeln('[GOV-POLICY] governance/policy.json is missing');
    exitCode = 1;
    return;
  }

  final Map<String, Object?> policy =
      (jsonDecode(policyFile.readAsStringSync()) as Map)
          .cast<String, Object?>();
  final List<Finding> findings = <Finding>[];

  _checkRequiredFiles(root, policy, findings);
  _checkContextBudgets(root, policy, findings);
  _checkTaskStates(root, policy, findings);
  _checkPublicApi(root, policy, findings);
  _checkApiSurface(root, findings);
  _checkSecrets(root, policy, findings);
  _checkPolicyExamples(policy, findings);
  _checkSources(root, policy, findings);
  _checkSdkBoundaries(root, findings);
  _checkExceptions(root, policy, findings);

  if (findings.isEmpty) {
    stdout.writeln('Nebula Governance: PASS');
    return;
  }

  stderr.writeln('Nebula Governance: FAIL (${findings.length} finding(s))');
  for (final Finding finding in findings) {
    stderr.writeln(finding);
  }
  exitCode = 1;
}

void _checkRequiredFiles(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final List<Object?> required = policy['required_files']! as List<Object?>;
  for (final Object? entry in required) {
    final String path = entry! as String;
    if (!File('${root.path}/$path').existsSync()) {
      findings.add(Finding('GOV-REQUIRED', 'missing required file: $path'));
    }
  }
}

void _checkContextBudgets(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final Map<String, Object?> limits =
      (policy['limits']! as Map).cast<String, Object?>();
  _checkLineLimit(
    root,
    'AGENTS.md',
    limits['max_agents_lines']! as int,
    'GOV-CONTEXT',
    findings,
  );
  _checkLineLimit(
    root,
    'docs/00_AI_HANDOFF.md',
    limits['max_handoff_lines']! as int,
    'GOV-CONTEXT',
    findings,
  );
}

void _checkLineLimit(
  Directory root,
  String relativePath,
  int maximum,
  String ruleId,
  List<Finding> findings,
) {
  final File file = File('${root.path}/$relativePath');
  if (!file.existsSync()) return;
  final int lines = file.readAsLinesSync().length;
  if (lines > maximum) {
    findings.add(
      Finding(ruleId, '$relativePath has $lines lines; maximum is $maximum'),
    );
  }
}

void _checkTaskStates(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final Set<String> allowed =
      (policy['allowed_task_states']! as List<Object?>).cast<String>().toSet();
  final File status = File('${root.path}/docs/STATUS.md');
  if (!status.existsSync()) return;

  final RegExp taskRow = RegExp(
    r'^\|\s*([A-Z][A-Z0-9]*-[^| ]+)\s*\|\s*([A-Z_]+)\s*\|',
  );
  final Set<String> seen = <String>{};
  for (final String line in status.readAsLinesSync()) {
    final RegExpMatch? match = taskRow.firstMatch(line);
    if (match == null) continue;
    final String taskId = match.group(1)!;
    final String state = match.group(2)!;
    if (!seen.add(taskId)) {
      findings.add(Finding('GOV-TASK', 'duplicate task ID: $taskId'));
    }
    if (!allowed.contains(state)) {
      findings.add(Finding('GOV-TASK', '$taskId has invalid state: $state'));
    }
  }
  if (seen.isEmpty) {
    findings.add(const Finding('GOV-TASK', 'no task rows found in STATUS.md'));
  }

  final RegExp fuzzyStatus = RegExp(
    r'基本完成|大致完成|almost done|mostly complete',
    caseSensitive: false,
  );
  if (fuzzyStatus.hasMatch(status.readAsStringSync())) {
    findings.add(
      const Finding('GOV-TASK', 'STATUS.md contains a non-verifiable state'),
    );
  }
}

void _checkPublicApi(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final File barrel = File('${root.path}/lib/nebula_sdk.dart');
  final File allowlist = File('${root.path}/governance/public_api.txt');
  if (!barrel.existsSync() || !allowlist.existsSync()) return;

  final Set<String> allowed = allowlist
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
  final RegExp exportPattern = RegExp(r"^export\s+'([^']+)';");
  final Set<String> actual = <String>{};
  for (final String line in barrel.readAsLinesSync()) {
    final RegExpMatch? match = exportPattern.firstMatch(line.trim());
    if (match != null) actual.add(match.group(1)!);
  }

  for (final String path in actual.difference(allowed)) {
    findings.add(Finding('API-EXPORT', 'unreviewed public export: $path'));
  }
  for (final String path in allowed.difference(actual)) {
    findings.add(Finding('API-EXPORT', 'allowlisted export is missing: $path'));
  }

  final Map<String, Object?> limits =
      (policy['limits']! as Map).cast<String, Object?>();
  final int maximum = limits['max_public_exports']! as int;
  if (actual.length > maximum) {
    findings.add(
      Finding(
        'API-BUDGET',
        'public export count ${actual.length} exceeds $maximum',
      ),
    );
  }
}

void _checkSources(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final List<Object?> patternEntries =
      policy['forbidden_source_patterns']! as List<Object?>;
  final List<Map<String, Object?>> patterns = patternEntries
      .map(
        (Object? entry) => (entry! as Map).cast<String, Object?>(),
      )
      .toList();
  final Map<String, Object?> limits =
      (policy['limits']! as Map).cast<String, Object?>();
  final int maxLines = limits['max_dart_file_lines']! as int;

  final Directory lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) return;
  final List<File> sources = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  for (final File source in sources) {
    final String relative = source.path.substring(root.path.length + 1);
    final List<String> lines = source.readAsLinesSync();
    if (lines.length > maxLines) {
      findings.add(
        Finding(
          'ARCH-FILE-BUDGET',
          '$relative has ${lines.length} lines; maximum is $maxLines',
        ),
      );
    }
    final String contents = lines.join('\n');
    for (final Map<String, Object?> pattern in patterns) {
      RegExp expression;
      try {
        expression = _patternFromPolicy(pattern);
      } on FormatException catch (error) {
        findings.add(
          Finding(
            'GOV-POLICY',
            '${pattern['id']! as String} invalid regex: $error',
          ),
        );
        continue;
      }
      final Set<String> allowedPaths =
          (pattern['allowed_paths'] as List<Object?>? ?? <Object?>[])
              .cast<String>()
              .toSet();
      if (allowedPaths.contains(relative)) {
        final int allowedMatchCount =
            pattern['allowed_match_count'] as int? ?? 0;
        final int actualMatchCount = expression.allMatches(contents).length;
        if (actualMatchCount <= allowedMatchCount) continue;
        findings.add(
          Finding(
            pattern['id']! as String,
            '$relative has $actualMatchCount matching occurrence(s); '
            'allowed budget is $allowedMatchCount: '
            '${pattern['reason']! as String}',
          ),
        );
        continue;
      }
      if (expression.hasMatch(contents)) {
        findings.add(
          Finding(
            pattern['id']! as String,
            '$relative: ${pattern['reason']! as String}',
          ),
        );
      }
    }
  }
}

void _checkSdkBoundaries(Directory root, List<Finding> findings) {
  for (final layer_graph.LayerGraphFinding finding
      in layer_graph.checkSdkLayerGraph(root)) {
    findings.add(Finding(finding.ruleId, finding.message));
  }
  for (final product_erasure.ProductErasureFinding finding
      in product_erasure.checkProductErasure(root)) {
    findings.add(Finding(finding.ruleId, finding.message));
  }
}

void _checkApiSurface(Directory root, List<Finding> findings) {
  final File snapshot = File('${root.path}/${api_surface.snapshotPath}');
  if (!snapshot.existsSync()) {
    findings.add(const Finding(
      'API-SURFACE',
      'snapshot missing; run: dart run tool/api_surface.dart --update',
    ));
    return;
  }
  final List<String> current = api_surface.collectApiSurface(root);
  final Set<String> recorded = snapshot
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
  final List<String> added = current.toSet().difference(recorded).toList()
    ..sort();
  final List<String> removed = recorded.difference(current.toSet()).toList()
    ..sort();
  if (added.isEmpty && removed.isEmpty) return;
  findings.add(Finding(
    'API-SURFACE',
    'public API surface drift (added=${added.length}, removed=${removed.length}); '
        'run `dart run tool/api_surface.dart --update` only after compatibility review',
  ));
}

void _checkSecrets(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final List<Object?> configured =
      (policy['secret_scan_ignore_paths'] as List<Object?>?)?.toList() ??
          <Object?>[];
  final List<String> ignorePaths =
      configured.map((Object? p) => p! as String).toList();
  final List<secret_scan.SecretHit> hits =
      secret_scan.scanForSecrets(root, ignorePaths: ignorePaths);
  for (final secret_scan.SecretHit hit in hits) {
    findings.add(Finding(hit.ruleId, '${hit.path}: ${hit.reason}'));
  }
}

void _checkPolicyExamples(
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final List<Object?> patternEntries =
      policy['forbidden_source_patterns']! as List<Object?>;
  for (final Object? raw in patternEntries) {
    final Map<String, Object?> pattern = (raw! as Map).cast<String, Object?>();
    final String id = pattern['id']! as String;
    RegExp expression;
    try {
      expression = _patternFromPolicy(pattern);
    } on FormatException catch (error) {
      findings.add(Finding('GOV-POLICY', '$id invalid regex: $error'));
      continue;
    }
    final List<Object?> allowedPaths =
        pattern['allowed_paths'] as List<Object?>? ?? <Object?>[];
    final Object? allowedMatchCount = pattern['allowed_match_count'];
    if (allowedPaths.isNotEmpty) {
      final Object? reason = pattern['allowed_path_reason'];
      if (reason is! String || reason.trim().isEmpty) {
        findings.add(
          Finding('GOV-POLICY', '$id allowed_paths require a reason'),
        );
      }
      if (allowedMatchCount is! int || allowedMatchCount <= 0) {
        findings.add(
          Finding(
            'GOV-POLICY',
            '$id allowed_paths require positive allowed_match_count',
          ),
        );
      }
    } else if (allowedMatchCount != null) {
      findings.add(
        Finding('GOV-POLICY', '$id allowed_match_count requires allowed_paths'),
      );
    }
    for (final Object? rawPath in allowedPaths) {
      final String path = rawPath! as String;
      if (!path.startsWith('lib/') || path.contains('*')) {
        findings.add(
          Finding('GOV-POLICY', '$id has invalid allowed_path: $path'),
        );
      }
    }
    final List<Object?> matches =
        pattern['examples_match'] as List<Object?>? ?? <Object?>[];
    final List<Object?> ignores =
        pattern['examples_ignore'] as List<Object?>? ?? <Object?>[];
    if (matches.isEmpty || ignores.isEmpty) {
      findings.add(
        Finding('GOV-POLICY', '$id requires match and ignore examples'),
      );
    }
    for (final Object? example in matches) {
      if (!expression.hasMatch(example! as String)) {
        findings.add(Finding('GOV-POLICY', '$id misses positive example'));
      }
    }
    for (final Object? example in ignores) {
      if (expression.hasMatch(example! as String)) {
        findings.add(Finding('GOV-POLICY', '$id hits negative example'));
      }
    }
  }
}

RegExp _patternFromPolicy(Map<String, Object?> pattern) => RegExp(
      pattern['pattern']! as String,
      caseSensitive: pattern['case_sensitive'] as bool? ?? true,
    );

void _checkExceptions(
  Directory root,
  Map<String, Object?> policy,
  List<Finding> findings,
) {
  final File file = File('${root.path}/governance/exceptions.json');
  if (!file.existsSync()) return;
  final Map<String, Object?> registry =
      (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  final List<Object?> exceptions = registry['exceptions']! as List<Object?>;
  final DateTime today = DateTime.now().toUtc();
  final Map<String, Object?> limits =
      (policy['limits']! as Map).cast<String, Object?>();
  final int maxDays = limits['max_exception_days']! as int;
  final DateTime latestAllowed = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: maxDays));
  const Set<String> required = <String>{
    'id',
    'rule_id',
    'path',
    'owner',
    'reason',
    'issue',
    'expires_on',
  };
  final Set<String> ids = <String>{};

  for (final Object? raw in exceptions) {
    final Map<String, Object?> exception =
        (raw! as Map).cast<String, Object?>();
    final String id = exception['id'] as String? ?? '<missing-id>';
    if (!ids.add(id)) {
      findings.add(Finding('GOV-EXCEPTION', 'duplicate exception: $id'));
    }
    for (final String field in required) {
      final Object? value = exception[field];
      if (value is! String || value.trim().isEmpty) {
        findings.add(Finding('GOV-EXCEPTION', '$id missing $field'));
      }
    }
    final String? path = exception['path'] as String?;
    if (path != null && path.contains('*')) {
      findings.add(
        Finding('GOV-EXCEPTION', '$id uses forbidden wildcard path'),
      );
    }
    final String? expiresOn = exception['expires_on'] as String?;
    final DateTime? expiry =
        expiresOn == null ? null : DateTime.tryParse(expiresOn);
    if (expiry == null) {
      findings.add(Finding('GOV-EXCEPTION', '$id has invalid expires_on'));
    } else if (expiry
        .isBefore(DateTime.utc(today.year, today.month, today.day))) {
      findings.add(Finding('GOV-EXCEPTION', '$id expired on $expiresOn'));
    } else if (expiry.isAfter(latestAllowed)) {
      findings.add(
        Finding(
          'GOV-EXCEPTION',
          '$id exceeds the maximum $maxDays-day exception window',
        ),
      );
    }
  }
}
