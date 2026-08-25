import 'dart:convert';
import 'dart:io';

final class LayerGraphFinding {
  const LayerGraphFinding(this.ruleId, this.message);
  final String ruleId;
  final String message;
  @override
  String toString() => '[$ruleId] $message';
}

final class _BoundaryPolicy {
  _BoundaryPolicy(Map<String, Object?> raw)
      : base = _strings(raw, 'base_modules'),
        capabilities = _strings(raw, 'capability_modules'),
        composition = _strings(raw, 'composition_modules'),
        testing = _strings(raw, 'testing_modules'),
        rootFiles = _strings(raw, 'root_files');
  final Set<String> base;
  final Set<String> capabilities;
  final Set<String> composition;
  final Set<String> testing;
  final Set<String> rootFiles;
  Set<String> get knownModules =>
      <String>{...base, ...capabilities, ...composition, ...testing};
}

Set<String> _strings(Map<String, Object?> map, String key) =>
    (map[key]! as List<Object?>).cast<String>().toSet();

List<LayerGraphFinding> checkSdkLayerGraph(Directory root) {
  final File policyFile =
      File('${root.path}/governance/sdk_boundary_policy.json');
  if (!policyFile.existsSync()) {
    return const <LayerGraphFinding>[
      LayerGraphFinding('ARCH-LAYER-POLICY', 'SDK boundary policy is missing'),
    ];
  }
  final Map<String, Object?> policyRoot =
      (jsonDecode(policyFile.readAsStringSync()) as Map)
          .cast<String, Object?>();
  final _BoundaryPolicy policy = _BoundaryPolicy(
    (policyRoot['layer_graph']! as Map).cast<String, Object?>(),
  );
  final Directory sourceRoot = Directory('${root.path}/lib/src');
  if (!sourceRoot.existsSync()) {
    return const <LayerGraphFinding>[
      LayerGraphFinding('ARCH-LAYER-SOURCE', 'lib/src is missing'),
    ];
  }
  final List<LayerGraphFinding> findings = <LayerGraphFinding>[];
  final List<File> files = sourceRoot
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in files) {
    final String relative = _relative(root, file);
    final String owner = _owner(relative, policy, findings);
    if (owner == 'unknown') continue;
    for (final String importPath in _imports(file.readAsStringSync())) {
      final String? targetRelative =
          _resolveInternalImport(relative, importPath);
      if (targetRelative == null) continue;
      final String targetOwner = _owner(targetRelative, policy, findings);
      if (targetOwner == 'unknown') continue;
      final String? violation = _violation(owner, targetOwner, policy);
      if (violation != null) {
        findings.add(LayerGraphFinding(
          'ARCH-LAYER-EDGE',
          '$relative -> $targetRelative ($owner -> $targetOwner): $violation',
        ));
      }
    }
  }
  return findings;
}

String _owner(
  String relative,
  _BoundaryPolicy policy,
  List<LayerGraphFinding> findings,
) {
  const String prefix = 'lib/src/';
  if (!relative.startsWith(prefix)) return 'external';
  final String local = relative.substring(prefix.length);
  if (!local.contains('/')) {
    if (policy.rootFiles.contains(local)) return 'root';
    findings.add(LayerGraphFinding(
      'ARCH-LAYER-UNCLASSIFIED',
      '$relative is an unclassified root production file',
    ));
    return 'unknown';
  }
  final String top = local.split('/').first;
  if (policy.knownModules.contains(top)) return top;
  findings.add(LayerGraphFinding(
    'ARCH-LAYER-UNCLASSIFIED',
    '$relative belongs to unclassified module $top',
  ));
  return 'unknown';
}

String? _violation(
  String source,
  String target,
  _BoundaryPolicy policy,
) {
  if (source == target) return null;
  if (target == 'testing' && source != 'testing') {
    return 'production code must not depend on testing';
  }
  if (source == 'root' || source == 'testing') return null;
  if (source == 'observability') {
    return target == 'testing'
        ? 'composition must not depend on testing'
        : null;
  }
  if (source == 'foundation') {
    return 'foundation must not depend on higher layers';
  }
  if (source == 'transport') {
    if (target == 'foundation' || target == 'root') return null;
    return 'transport may depend only on foundation or root contract';
  }
  if (source == 'storage') {
    if (target == 'foundation') return null;
    return 'storage may depend only on foundation';
  }
  if (policy.capabilities.contains(source)) {
    if (target == 'foundation' ||
        target == 'transport' ||
        target == 'storage' ||
        target == 'root') {
      return null;
    }
    if (policy.capabilities.contains(target)) {
      return 'sibling capabilities must use neutral ports/contracts';
    }
    return 'capability must not depend on composition/testing';
  }
  return 'unreviewed cross-module edge';
}

Iterable<String> _imports(String source) sync* {
  final RegExp pattern = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final RegExpMatch match in pattern.allMatches(source)) {
    yield match.group(1)!;
  }
}

String? _resolveInternalImport(String sourceRelative, String importPath) {
  if (importPath.startsWith('dart:')) return null;
  if (importPath.startsWith('package:')) {
    const String prefix = 'package:nebula_sdk/';
    if (!importPath.startsWith(prefix)) return null;
    final String packageRelative = importPath.substring(prefix.length);
    return packageRelative.startsWith('src/') ? 'lib/$packageRelative' : null;
  }
  if (!importPath.startsWith('.')) return null;
  final Uri base = Uri.file('/$sourceRelative');
  final Uri resolved = base.resolve(importPath);
  return resolved.path.startsWith('/lib/src/')
      ? resolved.path.substring(1)
      : null;
}

String _relative(Directory root, File file) =>
    file.absolute.path.substring(root.absolute.path.length + 1);

void main() {
  final List<LayerGraphFinding> findings =
      checkSdkLayerGraph(Directory.current);
  if (findings.isEmpty) {
    stdout.writeln('SDK Layer Graph Guard: PASS');
    return;
  }
  stderr.writeln('SDK Layer Graph Guard: FAIL (${findings.length})');
  for (final LayerGraphFinding finding in findings) {
    stderr.writeln(finding);
  }
  exitCode = 1;
}
