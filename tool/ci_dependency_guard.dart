import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('CI-DEPENDENCY-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> decodeObject(String text, String source) {
  final value = jsonDecode(text);
  if (value is! Map<String, dynamic>) fail('$source is not a JSON object');
  return value;
}

Map<String, dynamic> loadJsonFile(String path, String source) {
  final file = File(path);
  if (!file.existsSync()) fail('$source missing: $path');
  return decodeObject(file.readAsStringSync(), source);
}

Map<String, String> packageVersions(Map<String, dynamic> deps) {
  final packages = deps['packages'];
  if (packages is! List) fail('pub deps JSON lacks packages');
  final out = <String, String>{};
  for (final item in packages) {
    if (item is! Map<String, dynamic>) fail('invalid package entry');
    if (item['kind'] == 'root') continue;
    final name = item['name'];
    final version = item['version'];
    if (name is! String ||
        name.isEmpty ||
        version is! String ||
        version.isEmpty) {
      fail('invalid package name/version entry');
    }
    if (out.containsKey(name)) fail('duplicate package: $name');
    out[name] = version;
  }
  return out;
}

Map<String, dynamic> livePubDeps([String? depsJsonPath]) {
  if (depsJsonPath != null) {
    return loadJsonFile(depsJsonPath, 'deps JSON');
  }
  final result = Process.runSync(
    Platform.resolvedExecutable,
    ['pub', 'deps', '--json'],
  );
  if (result.exitCode != 0) {
    fail('dart pub deps failed: ${result.stderr}'.trim());
  }
  return decodeObject(result.stdout.toString(), 'dart pub deps');
}

void main(List<String> args) {
  const defaultSnapshot = 'governance/ci_dependency_snapshot.json';
  final si = args.indexOf('--snapshot');
  final snapshotPath =
      si >= 0 && si + 1 < args.length ? args[si + 1] : defaultSnapshot;
  final di = args.indexOf('--deps-json');
  final depsPath = di >= 0 && di + 1 < args.length ? args[di + 1] : null;
  final skipRuntimeVersion = args.contains('--skip-runtime-version');
  final skipImageIdentity = args.contains('--skip-image-identity');

  final snapshot = loadJsonFile(snapshotPath, 'dependency snapshot');
  if (snapshot['schema_version'] != 1) fail('unsupported snapshot schema');
  final expectedDart = snapshot['dart_version'];
  if (expectedDart is! String || expectedDart.isEmpty) {
    fail('snapshot dart_version missing');
  }
  if (!skipRuntimeVersion && !Platform.version.startsWith(expectedDart)) {
    fail('Dart runtime drift: expected $expectedDart, got ${Platform.version}');
  }
  if (!skipImageIdentity) {
    final identityPath = snapshot['image_identity_file'];
    final expectedIdentity = snapshot['image_identity'];
    if (identityPath is! String ||
        identityPath.isEmpty ||
        expectedIdentity is! String ||
        expectedIdentity.isEmpty) {
      fail('snapshot image identity is incomplete');
    }
    final identityFile = File(identityPath);
    if (!identityFile.existsSync()) {
      fail('CI image identity file missing: $identityPath');
    }
    final actualIdentity = identityFile.readAsStringSync().trim();
    if (actualIdentity != expectedIdentity) {
      fail('CI image drift: expected $expectedIdentity, got $actualIdentity');
    }
  }

  final rawExpected = snapshot['packages'];
  if (rawExpected is! Map<String, dynamic>) fail('snapshot packages missing');
  final expected = <String, String>{};
  for (final entry in rawExpected.entries) {
    if (entry.value is! String) fail('snapshot version invalid: ${entry.key}');
    expected[entry.key] = entry.value as String;
  }
  final actual = packageVersions(livePubDeps(depsPath));

  final missing = expected.keys.where((k) => !actual.containsKey(k)).toList()
    ..sort();
  final extra = actual.keys.where((k) => !expected.containsKey(k)).toList()
    ..sort();
  final drift = expected.keys
      .where((k) => actual[k] != null && actual[k] != expected[k])
      .toList()
    ..sort();
  if (missing.isNotEmpty || extra.isNotEmpty || drift.isNotEmpty) {
    final lines = <String>[];
    if (missing.isNotEmpty) lines.add('missing: ${missing.join(', ')}');
    if (extra.isNotEmpty) lines.add('extra: ${extra.join(', ')}');
    for (final name in drift) {
      lines.add('$name: expected ${expected[name]}, got ${actual[name]}');
    }
    fail('dependency resolution drift:\n  ${lines.join('\n  ')}');
  }
  stdout.writeln(
    'CI-DEPENDENCY-GUARD: PASS '
    '(${actual.length} packages; Dart $expectedDart)',
  );
}
