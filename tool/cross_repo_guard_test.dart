import 'dart:io';

void expect(bool ok, String label) {
  if (!ok) {
    stderr.writeln('FAIL $label');
    exit(1);
  }
  stdout.writeln('PASS $label');
}

ProcessResult runDart(List<String> args) =>
    Process.runSync(Platform.resolvedExecutable, ['run', ...args]);

void main() {
  expect(
    runDart(['tool/cross_repo_guard.dart', '--self-check']).exitCode == 0,
    'cross-repo schema self-check',
  );
  expect(
    runDart([
          'tool/cross_repo_guard.dart',
          '--story',
          'S1-F03-001',
          '--repo',
          Directory.current.path,
        ]).exitCode ==
        0,
    'SDK Story accepts SDK execution repo',
  );
  final temp = Directory.systemTemp.createTempSync('cross-repo-wrong-');
  try {
    expect(
      runDart([
            'tool/cross_repo_guard.dart',
            '--story',
            'S1-F03-001',
            '--repo',
            temp.path,
          ]).exitCode !=
          0,
      'wrong execution repo is blocked',
    );
  } finally {
    temp.deleteSync(recursive: true);
  }
  expect(
    runDart(['tool/task_source_guard.dart', '--story', 'S1-F01-001'])
            .exitCode !=
        0,
    'Story in REVIEW cannot be resumed by implementation Agent',
  );
  stdout.writeln('Cross-repo guard regression: PASS');
}
