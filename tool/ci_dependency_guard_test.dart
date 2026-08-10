import 'dart:convert';
import 'dart:io';

void expect(bool ok, String label) {
  if (!ok) {
    stderr.writeln('FAIL $label');
    exit(1);
  }
  stdout.writeln('PASS $label');
}

ProcessResult guard(String snapshot, String deps) => Process.runSync(
      Platform.resolvedExecutable,
      [
        'run',
        'tool/ci_dependency_guard.dart',
        '--snapshot',
        snapshot,
        '--deps-json',
        deps,
        '--skip-runtime-version',
        '--skip-image-identity',
      ],
    );

void writeJson(String path, Object value) {
  File(path).writeAsStringSync('${jsonEncode(value)}\n');
}

Map<String, Object> deps(Map<String, String> packages) => {
      'root': 'x',
      'packages': [
        {'name': 'x', 'version': '1.0.0', 'kind': 'root'},
        for (final entry in packages.entries)
          {
            'name': entry.key,
            'version': entry.value,
            'kind': 'transitive',
          },
      ],
    };

void main() {
  final dir = Directory.systemTemp.createTempSync('ci-deps-guard-');
  try {
    final snapshot = '${dir.path}/snapshot.json';
    final actual = '${dir.path}/deps.json';
    writeJson(snapshot, {
      'schema_version': 1,
      'dart_version': '0.0.0-test',
      'packages': {'a': '1.0.0', 'b': '2.0.0'},
    });
    writeJson(actual, deps({'a': '1.0.0', 'b': '2.0.0'}));
    expect(guard(snapshot, actual).exitCode == 0, 'exact resolution passes');

    writeJson(actual, deps({'a': '9.0.0', 'b': '2.0.0'}));
    expect(guard(snapshot, actual).exitCode != 0, 'version drift blocks');

    writeJson(actual, deps({'a': '1.0.0'}));
    expect(guard(snapshot, actual).exitCode != 0, 'missing dependency blocks');

    writeJson(actual, deps({'a': '1.0.0', 'b': '2.0.0', 'c': '3.0.0'}));
    expect(guard(snapshot, actual).exitCode != 0, 'extra dependency blocks');
  } finally {
    dir.deleteSync(recursive: true);
  }
  stdout.writeln('CI dependency guard regression: PASS');
}
