import 'dart:convert';
import 'dart:io';

final class ProductErasureFinding {
  const ProductErasureFinding(this.ruleId, this.message);
  final String ruleId;
  final String message;
  @override
  String toString() => '[$ruleId] $message';
}

final class _ProductPolicy {
  _ProductPolicy(Map<String, Object?> raw)
      : consumerTokens = _strings(raw, 'consumer_tokens'),
        packageIds = _strings(raw, 'consumer_package_ids'),
        consumerOrigins = _strings(raw, 'consumer_origins'),
        allowedOrigins = _strings(raw, 'allowed_http_origins'),
        allowedDependencies = _strings(raw, 'allowed_runtime_dependencies'),
        allowedPackageImports = _strings(raw, 'allowed_package_imports'),
        uiIdentifiers = _strings(raw, 'ui_navigation_identifiers');

  final Set<String> consumerTokens;
  final Set<String> packageIds;
  final Set<String> consumerOrigins;
  final Set<String> allowedOrigins;
  final Set<String> allowedDependencies;
  final Set<String> allowedPackageImports;
  final Set<String> uiIdentifiers;
}

Set<String> _strings(Map<String, Object?> map, String key) =>
    (map[key] as List<Object?>? ?? <Object?>[]).cast<String>().toSet();

List<ProductErasureFinding> checkProductErasure(Directory root) {
  final File policyFile =
      File('${root.path}/governance/sdk_boundary_policy.json');
  if (!policyFile.existsSync()) {
    return const <ProductErasureFinding>[
      ProductErasureFinding(
          'ARCH-PRODUCT-POLICY', 'SDK boundary policy is missing'),
    ];
  }
  final Map<String, Object?> policyRoot =
      (jsonDecode(policyFile.readAsStringSync()) as Map)
          .cast<String, Object?>();
  final _ProductPolicy policy = _ProductPolicy(
    (policyRoot['product_erasure']! as Map).cast<String, Object?>(),
  );
  final List<ProductErasureFinding> findings = <ProductErasureFinding>[];
  _checkDependencies(root, policy, findings);

  final Directory lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) {
    findings.add(
        const ProductErasureFinding('ARCH-PRODUCT-SOURCE', 'lib is missing'));
    return findings;
  }
  final List<File> files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in files) {
    final String relative =
        file.absolute.path.substring(root.absolute.path.length + 1);
    final String executable = _stripComments(file.readAsStringSync());
    final String folded = executable.toLowerCase();

    for (final String token in policy.consumerTokens) {
      if (folded.contains(token.toLowerCase())) {
        findings.add(ProductErasureFinding(
          'ARCH-PRODUCT-TOKEN',
          '$relative contains consumer/product token "$token" in executable code',
        ));
      }
    }
    for (final String packageId in policy.packageIds) {
      if (folded.contains(packageId.toLowerCase())) {
        findings.add(ProductErasureFinding(
          'ARCH-PRODUCT-PACKAGE-ID',
          '$relative contains consumer package id "$packageId"',
        ));
      }
    }
    for (final String origin in policy.consumerOrigins) {
      if (folded.contains(origin.toLowerCase())) {
        findings.add(ProductErasureFinding(
          'ARCH-PRODUCT-ORIGIN',
          '$relative contains consumer-specific origin "$origin"',
        ));
      }
    }
    _checkUiAndPackages(relative, executable, policy, findings);
    _checkOrigins(relative, executable, policy, findings);
  }
  return findings;
}

void _checkDependencies(
  Directory root,
  _ProductPolicy policy,
  List<ProductErasureFinding> findings,
) {
  final File pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    findings.add(const ProductErasureFinding(
      'ARCH-RUNTIME-DEPENDENCY',
      'pubspec.yaml is missing',
    ));
    return;
  }
  final Set<String> actual = _runtimeDependencies(pubspec.readAsLinesSync());
  for (final String dependency
      in actual.difference(policy.allowedDependencies)) {
    findings.add(ProductErasureFinding(
      'ARCH-RUNTIME-DEPENDENCY',
      'unreviewed runtime dependency "$dependency"',
    ));
  }
  for (final String expected in policy.allowedDependencies.difference(actual)) {
    findings.add(ProductErasureFinding(
      'ARCH-RUNTIME-DEPENDENCY',
      'reviewed runtime dependency "$expected" is missing',
    ));
  }
}

Set<String> _runtimeDependencies(List<String> lines) {
  final Set<String> result = <String>{};
  int start = -1;
  for (int i = 0; i < lines.length; i++) {
    if (RegExp(r'^dependencies\s*:').hasMatch(lines[i])) {
      start = i;
      if (RegExp(r'^dependencies\s*:\s*\{\s*\}\s*(?:#.*)?$')
          .hasMatch(lines[i])) {
        return result;
      }
      break;
    }
  }
  if (start < 0) return result;
  for (int i = start + 1; i < lines.length; i++) {
    final String line = lines[i];
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) break;
    final RegExpMatch? match =
        RegExp(r'^\s+([A-Za-z0-9_-]+)\s*:').firstMatch(line);
    if (match != null) result.add(match.group(1)!);
  }
  return result;
}

void _checkUiAndPackages(
  String relative,
  String executable,
  _ProductPolicy policy,
  List<ProductErasureFinding> findings,
) {
  if (executable.contains('package:flutter/')) {
    findings.add(ProductErasureFinding(
      'ARCH-FLUTTER-COUPLING',
      '$relative imports Flutter UI/runtime code',
    ));
  }
  for (final String identifier in policy.uiIdentifiers) {
    final RegExp pattern = RegExp('\\b${RegExp.escape(identifier)}\\b');
    if (pattern.hasMatch(executable)) {
      findings.add(ProductErasureFinding(
        'ARCH-UI-COUPLING',
        '$relative contains UI/navigation identifier "$identifier"',
      ));
    }
  }
  final RegExp packageImport = RegExp(
    r'''^\s*import\s+['"]package:([^/'"]+)/''',
    multiLine: true,
  );
  for (final RegExpMatch match in packageImport.allMatches(executable)) {
    final String package = match.group(1)!;
    if (package == 'nebula_sdk') continue;
    if (!policy.allowedPackageImports.contains(package)) {
      findings.add(ProductErasureFinding(
        'ARCH-PACKAGE-IMPORT',
        '$relative imports unreviewed package "$package"',
      ));
    }
  }
}

void _checkOrigins(
  String relative,
  String executable,
  _ProductPolicy policy,
  List<ProductErasureFinding> findings,
) {
  final RegExp originPattern = RegExp(
    r'''https?://[A-Za-z0-9._~%+-]+(?::[0-9]+)?''',
    caseSensitive: false,
  );
  for (final RegExpMatch match in originPattern.allMatches(executable)) {
    final String origin = match.group(0)!;
    final bool allowed = policy.allowedOrigins.any(
      (String reviewed) => reviewed.toLowerCase() == origin.toLowerCase(),
    );
    if (!allowed) {
      findings.add(ProductErasureFinding(
        'ARCH-HARDCODED-ORIGIN',
        '$relative contains hard-coded origin "$origin"',
      ));
    }
  }
}

String _stripComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  int blockDepth = 0;
  while (i < source.length) {
    if (blockDepth > 0) {
      if (source.startsWith('/*', i)) {
        blockDepth++;
        i += 2;
        continue;
      }
      if (source.startsWith('*/', i)) {
        blockDepth--;
        i += 2;
        continue;
      }
      if (source[i] == '\n') out.write('\n');
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      blockDepth = 1;
      i += 2;
      continue;
    }
    if (_startsString(source, i)) {
      i = _copyString(source, i, out);
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

bool _startsString(String source, int index) {
  final String char = source[index];
  if (char == "'" || char == '"') return true;
  if (char != 'r' || index + 1 >= source.length) return false;
  if (index > 0 && RegExp(r'[A-Za-z0-9_$]').hasMatch(source[index - 1])) {
    return false;
  }
  final String next = source[index + 1];
  return next == "'" || next == '"';
}

int _copyString(String source, int start, StringBuffer out) {
  int i = start;
  bool raw = false;
  if (source[i] == 'r') {
    raw = true;
    out.write('r');
    i++;
  }
  final String quote = source[i];
  final String delimiter = source.startsWith(quote * 3, i) ? quote * 3 : quote;
  out.write(delimiter);
  i += delimiter.length;
  while (i < source.length) {
    if (source.startsWith(delimiter, i)) {
      out.write(delimiter);
      return i + delimiter.length;
    }
    if (!raw && source[i] == r'\' && i + 1 < source.length) {
      out.write(source.substring(i, i + 2));
      i += 2;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return i;
}

void main() {
  final List<ProductErasureFinding> findings =
      checkProductErasure(Directory.current);
  if (findings.isEmpty) {
    stdout.writeln('SDK Product-Erasure Guard: PASS');
    return;
  }
  stderr.writeln('SDK Product-Erasure Guard: FAIL (${findings.length})');
  for (final ProductErasureFinding finding in findings) {
    stderr.writeln(finding);
  }
  exitCode = 1;
}
