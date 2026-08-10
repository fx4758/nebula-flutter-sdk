import 'dart:convert';
import 'dart:io';

void expect(bool ok, String label) {
  if (!ok) {
    stderr.writeln('FAIL $label');
    exit(1);
  }
  stdout.writeln('PASS $label');
}

ProcessResult mode(String path) => Process.runSync(
      Platform.resolvedExecutable,
      ['run', 'tool/coordinator_publication_mode.dart', '--event-path', path],
    );

void writeEvent(
  String path, {
  required String base,
  List<String> labels = const [],
}) {
  File(path).writeAsStringSync(
    jsonEncode({
      'pull_request': {
        'base': {'ref': base},
        'labels': [
          for (final name in labels) {'name': name},
        ],
      },
    }),
  );
}

void main() {
  final d = Directory.systemTemp.createTempSync('coord-publication-');
  try {
    final p = '${d.path}/event.json';
    writeEvent(p, base: 'main');
    var r = mode(p);
    expect(
      r.exitCode == 0 && r.stdout.toString().trim() == 'implementation',
      'unlabeled main PR remains implementation mode',
    );

    writeEvent(p, base: 'main', labels: ['coordinator-publication']);
    r = mode(p);
    expect(
      r.exitCode == 0 && r.stdout.toString().trim() == 'coordinator',
      'explicit publication label enables coordinator mode',
    );

    writeEvent(p, base: 'dev', labels: ['coordinator-publication']);
    r = mode(p);
    expect(
      r.exitCode == 0 && r.stdout.toString().trim() == 'implementation',
      'label cannot enable coordinator mode for non-main target',
    );
  } finally {
    d.deleteSync(recursive: true);
  }
  stdout.writeln('Coordinator publication mode regression: PASS');
}
