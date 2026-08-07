import 'dart:io';

void expect(bool condition, String label) {
  if (!condition) {
    stderr.writeln('FAIL $label');
    exit(1);
  }
  stdout.writeln('PASS $label');
}

ProcessResult git(String repo, List<String> args) =>
    Process.runSync('git', ['-C', repo, ...args]);

ProcessResult guard(String repo, String base) => Process.runSync(
      Platform.resolvedExecutable,
      [
        'run',
        'tool/platform_api_guard.dart',
        '--story',
        'S1-F02-001',
        '--backend-repo',
        repo,
        '--base',
        base,
      ],
    );

void write(String path, String value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(value);
}

void main() {
  final temp =
      Directory.systemTemp.createTempSync('nebula-platform-guard-test-');
  try {
    final repo = temp.path;
    expect(git(repo, ['init', '-q']).exitCode == 0, 'temp git init');
    git(repo, ['config', 'user.email', 'guard@test.local']);
    git(repo, ['config', 'user.name', 'Guard']);
    write('$repo/internal/module/runtimeconfig/handler.go',
        'package runtimeconfig\n');
    write('$repo/internal/module/runtimeconfig/runtimeconfig_test.go',
        'package runtimeconfig\n');
    write('$repo/internal/router/router.go', 'package router\n');
    write('$repo/sdk/CONTRACT.md', 'contract\n');
    git(repo, ['add', '.']);
    expect(git(repo, ['commit', '-qm', 'baseline']).exitCode == 0,
        'baseline commit');
    final base = git(repo, ['rev-parse', 'HEAD']).stdout.toString().trim();

    File('$repo/internal/module/runtimeconfig/runtimeconfig_test.go')
        .writeAsStringSync('// test only\n', mode: FileMode.append);
    expect(guard(repo, base).exitCode == 0,
        'READ_ONLY permits runtime-config test changes');
    git(repo, [
      'checkout',
      '--',
      'internal/module/runtimeconfig/runtimeconfig_test.go'
    ]);

    File('$repo/internal/module/runtimeconfig/handler.go')
        .writeAsStringSync('// shortcut\n', mode: FileMode.append);
    expect(guard(repo, base).exitCode != 0,
        'READ_ONLY blocks runtime-config production changes');
    git(repo, ['checkout', '--', 'internal/module/runtimeconfig/handler.go']);

    File('$repo/internal/router/router.go')
        .writeAsStringSync('// new route\n', mode: FileMode.append);
    expect(guard(repo, base).exitCode != 0, 'READ_ONLY blocks router changes');
    git(repo, ['checkout', '--', 'internal/router/router.go']);

    File('$repo/sdk/CONTRACT.md')
        .writeAsStringSync('new field\n', mode: FileMode.append);
    expect(guard(repo, base).exitCode != 0,
        'READ_ONLY blocks Platform contract changes');
  } finally {
    temp.deleteSync(recursive: true);
  }
  stdout.writeln('Platform API guard regression: PASS');
}
