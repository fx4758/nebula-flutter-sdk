/// API surface snapshot tool (G0-03).
///
/// Scans every library exported from `lib/nebula_sdk.dart`, extracts the
/// top-level public symbols (classes, enums, typedefs, consts, top-level
/// functions) and compares them against the frozen snapshot in
/// `governance/api_surface.snapshot`. Any added/removed public symbol is a
/// surface change that must be explicitly confirmed by updating the snapshot:
///
/// ```bash
/// dart run tool/api_surface.dart            # validate (non-zero exit on drift)
/// dart run tool/api_surface.dart --update   # record the current surface
/// ```
///
/// The snapshot is a compatibility gate, not a code generator: symbol-level
/// existence is pinned; member-level signatures are a future G-stage concern.
library;

import 'dart:io';

/// The barrel file that defines the public API.
const String barrelPath = 'lib/nebula_sdk.dart';

/// The frozen snapshot location (relative to repository root).
const String snapshotPath = 'governance/api_surface.snapshot';

void main(List<String> args) {
  final Directory root = Directory.current;
  final bool update = args.contains('--update');

  final List<String> surface = collectApiSurface(root);
  final File snapshot = File('${root.path}/$snapshotPath');

  if (update) {
    snapshot.writeAsStringSync('${surface.join('\n')}\n');
    stdout.writeln(
        'API surface snapshot updated: ${surface.length} symbol(s) -> $snapshotPath');
    return;
  }

  if (!snapshot.existsSync()) {
    stderr.writeln(
        '[API-SURFACE] $snapshotPath is missing; run: dart run tool/api_surface.dart --update');
    exitCode = 1;
    return;
  }

  final List<String> recorded = snapshot
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  final Set<String> currentSet = surface.toSet();
  final Set<String> recordedSet = recorded.toSet();

  final List<String> added = currentSet.difference(recordedSet).toList()
    ..sort();
  final List<String> removed = recordedSet.difference(currentSet).toList()
    ..sort();

  if (added.isEmpty && removed.isEmpty) {
    stdout.writeln(
        'API surface: PASS (${surface.length} symbol(s) match snapshot)');
    return;
  }

  stderr.writeln('[API-SURFACE] public API surface drift detected');
  for (final String symbol in added) {
    stderr.writeln('  + added:   $symbol');
  }
  for (final String symbol in removed) {
    stderr.writeln('  - removed: $symbol');
  }
  stderr.writeln(
      '  Run `dart run tool/api_surface.dart --update` only after explicit '
      'compatibility review.');
  exitCode = 1;
}

/// Collects the sorted top-level public symbol lines for every exported
/// library. Reused by the governance guard (`tool/governance.dart`).
List<String> collectApiSurface(Directory root) {
  final File barrel = File('${root.path}/$barrelPath');
  if (!barrel.existsSync()) return <String>[];

  final RegExp exportPattern = RegExp(r"^export\s+'([^']+)';");
  final List<String> lines = <String>[];

  for (final String exportLine in barrel.readAsLinesSync()) {
    final RegExpMatch? match = exportPattern.firstMatch(exportLine.trim());
    if (match == null) continue;
    final String relative = match.group(1)!;
    final File source = File('${root.path}/lib/$relative');
    if (!source.existsSync()) continue;
    lines.addAll(_symbolsIn(relative, source.readAsStringSync()));
  }

  lines.sort();
  return lines;
}

final RegExp _classPattern = RegExp(
  r'^(?:abstract\s+interface|sealed|abstract|base|final|mixin)?\s*class\s+([A-Z]\w*)',
);
final RegExp _enumPattern = RegExp(r'^enum\s+([A-Z]\w*)');
final RegExp _typedefPattern = RegExp(r'^typedef\s+(\w+)');
final RegExp _constPattern = RegExp(
  r'^const\s+(?:final\s+)?[\w<>\[\].?]+\s+([a-z_]\w*)\s*=',
);
final RegExp _functionPattern = RegExp(
  r'^([A-Za-z_][\w<>.?]*)\s+([a-z_]\w*)\s*\(',
);

/// Extracts top-level symbol lines (`path kind name`) from one source file.
/// Only zero-indented declarations are considered, which excludes class
/// members; comment lines are skipped before matching.
List<String> _symbolsIn(String relative, String source) {
  final String stripped = _stripComments(source);
  final List<String> result = <String>[];
  for (final String rawLine in stripped.split('\n')) {
    final String line = rawLine.trimRight();
    if (line.isEmpty || line.startsWith('//')) continue;

    final RegExpMatch? classMatch = _classPattern.firstMatch(line);
    if (classMatch != null) {
      result.add('$relative class ${classMatch.group(1)}');
      continue;
    }
    final RegExpMatch? enumMatch = _enumPattern.firstMatch(line);
    if (enumMatch != null) {
      result.add('$relative enum ${enumMatch.group(1)}');
      continue;
    }
    final RegExpMatch? typedefMatch = _typedefPattern.firstMatch(line);
    if (typedefMatch != null) {
      result.add('$relative typedef ${typedefMatch.group(1)}');
      continue;
    }
    final RegExpMatch? constMatch = _constPattern.firstMatch(line);
    if (constMatch != null) {
      result.add('$relative const ${constMatch.group(1)}');
      continue;
    }
    // Top-level function: a zero-indented line ending in `(` whose name starts
    // lowercase, with a non-keyword return type prefix.
    final RegExpMatch? fnMatch = _functionPattern.firstMatch(line);
    if (fnMatch != null) {
      final String returnType = fnMatch.group(1)!;
      if (!_isKeyword(returnType)) {
        result.add('$relative function ${fnMatch.group(2)}');
      }
    }
  }
  return result;
}

String _stripComments(String source) {
  final StringBuffer buffer = StringBuffer();
  final List<String> lines = source.split('\n');
  bool inBlock = false;
  for (final String line in lines) {
    if (inBlock) {
      final int end = line.indexOf('*/');
      if (end >= 0) {
        inBlock = false;
        buffer.writeln(line.substring(end + 2));
      }
      continue;
    }
    final int blockStart = line.indexOf('/*');
    if (blockStart >= 0) {
      inBlock = true;
      buffer.writeln(line.substring(0, blockStart));
      continue;
    }
    buffer.writeln(line);
  }
  return buffer.toString();
}

const Set<String> _keywords = <String>{
  'void',
  'if',
  'for',
  'while',
  'return',
  'import',
  'export',
  'library',
  'part',
  'abstract',
  'base',
  'final',
  'sealed',
  'const',
  'class',
  'enum',
  'typedef',
  'extends',
  'implements',
  'with',
  'required',
  'factory',
  'static',
  'this',
  'super',
  'new',
  'assert',
  'switch',
  'case',
  'break',
  'continue',
  'try',
  'catch',
  'finally',
  'throw',
  'rethrow',
  'async',
  'await',
  'yield',
  'var',
  'late',
  'override',
  'get',
  'set',
  'operator',
  'extension',
  'mixin',
};

bool _isKeyword(String token) => _keywords.contains(token);
