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

/// Removes Dart comments while preserving line structure.
///
/// This is a character-level scanner, not a line-level `indexOf` scan: a naive
/// search for `/*` mistakes URL/path wildcards inside doc comments and string
/// literals (e.g. ``/// endpoints live under `/api/v1/mobile/auth/*` ``) for a
/// block-comment opener and silently swallows every declaration that follows,
/// which surfaces as a bogus API-SURFACE "removed symbol" drift. Comment
/// openers are therefore only honoured in real code context.
///
/// Handled: `//` line comments, `/* */` block comments (Dart allows nesting),
/// single/double-quoted strings, triple-quoted strings, raw (`r'...'`) strings,
/// backslash escapes and `${...}` interpolation (which may nest strings).
/// Newlines are always preserved so callers can keep matching per line.
String _stripComments(String source) {
  final StringBuffer out = StringBuffer();
  final int length = source.length;
  int index = 0;
  int blockDepth = 0;

  while (index < length) {
    final String char = source[index];

    if (blockDepth > 0) {
      if (_matchesAt(source, index, '/*')) {
        blockDepth++;
        index += 2;
        continue;
      }
      if (_matchesAt(source, index, '*/')) {
        blockDepth--;
        index += 2;
        continue;
      }
      // Keep newlines so line-based matching stays aligned with the source.
      if (char == '\n') out.write('\n');
      index++;
      continue;
    }

    if (_matchesAt(source, index, '//')) {
      while (index < length && source[index] != '\n') {
        index++;
      }
      continue;
    }
    if (_matchesAt(source, index, '/*')) {
      blockDepth = 1;
      index += 2;
      continue;
    }
    if (_startsStringLiteral(source, index)) {
      index = _copyStringLiteral(source, index, out);
      continue;
    }

    out.write(char);
    index++;
  }
  return out.toString();
}

bool _matchesAt(String source, int index, String token) =>
    source.startsWith(token, index);

bool _isIdentifierChar(String char) => RegExp(r'[A-Za-z0-9_$]').hasMatch(char);

/// True when [index] opens a string literal, including the `r` of a raw string.
bool _startsStringLiteral(String source, int index) {
  final String char = source[index];
  if (char == "'" || char == '"') return true;
  if (char != 'r' || index + 1 >= source.length) return false;
  // `r` is a raw-string prefix only when it is not part of an identifier.
  if (index > 0 && _isIdentifierChar(source[index - 1])) return false;
  final String next = source[index + 1];
  return next == "'" || next == '"';
}

/// Copies the string literal beginning at [start] verbatim into [out] and
/// returns the index just past its closing delimiter.
int _copyStringLiteral(String source, int start, StringBuffer out) {
  final int length = source.length;
  int index = start;
  bool raw = false;

  if (source[index] == 'r') {
    raw = true;
    out.write('r');
    index++;
  }

  final String quote = source[index];
  String delimiter = quote;
  if (_matchesAt(source, index, quote * 3)) {
    delimiter = quote * 3;
  }
  out.write(delimiter);
  index += delimiter.length;

  while (index < length) {
    final String char = source[index];
    if (!raw && char == r'\' && index + 1 < length) {
      out.write(source.substring(index, index + 2));
      index += 2;
      continue;
    }
    if (!raw && _matchesAt(source, index, r'${')) {
      out.write(r'${');
      index = _copyInterpolation(source, index + 2, out);
      continue;
    }
    if (_matchesAt(source, index, delimiter)) {
      out.write(delimiter);
      return index + delimiter.length;
    }
    out.write(char);
    index++;
  }
  return length; // Unterminated literal: consume to EOF rather than mis-parse.
}

/// Copies a `${...}` interpolation body (nested strings/braces included) and
/// returns the index just past its closing brace.
int _copyInterpolation(String source, int start, StringBuffer out) {
  final int length = source.length;
  int index = start;
  int depth = 1;

  while (index < length) {
    final String char = source[index];
    if (_startsStringLiteral(source, index)) {
      index = _copyStringLiteral(source, index, out);
      continue;
    }
    if (char == '{') depth++;
    if (char == '}') depth--;
    out.write(char);
    index++;
    if (depth == 0) return index;
  }
  return length;
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
