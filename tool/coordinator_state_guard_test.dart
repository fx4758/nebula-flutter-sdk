import 'dart:io';

void expect(bool ok, String label) {
  if (!ok) {
    stderr.writeln('FAIL $label');
    exit(1);
  }
  stdout.writeln('PASS $label');
}

ProcessResult git(String repo, List<String> args) =>
    Process.runSync('git', ['-C', repo, ...args]);
ProcessResult guard(String repo, String base, {bool coordinator = false}) =>
    Process.runSync(
      Platform.resolvedExecutable,
      [
        'run',
        'tool/coordinator_state_guard.dart',
        '--repo',
        repo,
        '--base',
        base,
        if (coordinator) '--coordinator',
      ],
    );

void write(String root, String path, String content) {
  final f = File('$root/$path');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}

void main() {
  final temp = Directory.systemTemp.createTempSync('coord-state-');
  try {
    final r = temp.path;
    expect(git(r, ['init', '-q']).exitCode == 0, 'temp git init');
    git(r, ['config', 'user.email', 'guard@test.local']);
    git(r, ['config', 'user.name', 'Guard']);
    write(r, 'lib/a.dart', 'a\n');
    write(r, 'docs/multi_agent/task_board.json', '{}\n');
    git(r, ['add', '.']);
    expect(
        git(r, ['commit', '-qm', 'baseline']).exitCode == 0, 'baseline commit');
    final base = git(r, ['rev-parse', 'HEAD']).stdout.toString().trim();
    write(r, 'lib/a.dart', 'b\n');
    expect(guard(r, base).exitCode == 0, 'implementation file change allowed');
    git(r, ['checkout', '--', 'lib/a.dart']);
    write(r, 'docs/multi_agent/task_board.json', '{"status":"DELIVERED"}\n');
    expect(guard(r, base).exitCode != 0,
        'implementation Agent task-board write blocked');
    expect(guard(r, base, coordinator: true).exitCode == 0,
        'explicit Coordinator operation allowed');
  } finally {
    temp.deleteSync(recursive: true);
  }
  stdout.writeln('Coordinator-state guard regression: PASS');
}
