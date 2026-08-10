import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('COORDINATOR-STATE-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> decodeBoard(String text, String source) {
  final value = jsonDecode(text);
  if (value is! Map<String, dynamic>) fail('$source task board invalid');
  return value;
}

Map<String, dynamic> loadHeadBoard() {
  final f = File('docs/multi_agent/task_board.json');
  if (!f.existsSync()) fail('task_board.json missing');
  return decodeBoard(f.readAsStringSync(), 'HEAD');
}

List<String> gitLines(String repo, List<String> args) {
  final r = Process.runSync('git', ['-C', repo, ...args]);
  if (r.exitCode != 0) fail('git ${args.join(' ')} failed: ${r.stderr}'.trim());
  return r.stdout
      .toString()
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

Map<String, dynamic> loadBaseBoard(String repo, String base) {
  final r = Process.runSync('git', [
    '-C',
    repo,
    'show',
    '$base:docs/multi_agent/task_board.json',
  ]);
  if (r.exitCode != 0) {
    fail('cannot read base task board at $base: ${r.stderr}'.trim());
  }
  return decodeBoard(r.stdout.toString(), 'BASE');
}

List<String> protectedPaths(Map<String, dynamic> board, String source) {
  final cross = board['cross_repo_governance'];
  if (cross is! Map<String, dynamic>) {
    fail('$source cross_repo_governance missing');
  }
  final paths = cross['coordinator_owned_paths'];
  if (paths is! List || paths.isEmpty) {
    fail('$source coordinator_owned_paths missing');
  }
  return paths.cast<String>();
}

Set<String> changes(String repo, String base) {
  final out = <String>{};
  out.addAll(gitLines(repo, ['diff', '--name-only', '$base...HEAD']));
  out.addAll(gitLines(repo, ['diff', '--name-only']));
  out.addAll(gitLines(repo, ['diff', '--cached', '--name-only']));
  out.addAll(gitLines(repo, ['ls-files', '--others', '--exclude-standard']));
  return out;
}

void main(List<String> args) {
  final headBoard = loadHeadBoard();
  final headProtected = protectedPaths(headBoard, 'HEAD');
  if (args.contains('--self-check')) {
    stdout.writeln(
      'COORDINATOR-STATE-GUARD: PASS (${headProtected.length} protected paths)',
    );
    return;
  }

  var repo = Directory.current.path;
  final ri = args.indexOf('--repo');
  if (ri >= 0 && ri + 1 < args.length) repo = args[ri + 1];
  final bi = args.indexOf('--base');
  if (bi < 0 || bi + 1 >= args.length) {
    fail('usage: --base <commit> [--repo <path>] [--coordinator]');
  }
  final base = args[bi + 1];
  gitLines(repo, ['cat-file', '-e', '$base^{commit}']);

  // Trust neither side alone. BASE prevents a PR from deleting protection
  // entries to bypass the guard; HEAD lets a Coordinator publication add new
  // protected paths that become effective immediately after landing.
  final baseBoard = loadBaseBoard(repo, base);
  final protected = <String>{
    ...protectedPaths(baseBoard, 'BASE'),
    ...headProtected,
  };
  final touched = changes(repo, base).where(protected.contains).toList()
    ..sort();

  if (args.contains('--coordinator')) {
    stdout.writeln(
      'COORDINATOR-STATE-GUARD: PASS '
      '(explicit Coordinator publication; protected changes=${touched.length})',
    );
    for (final path in touched) {
      stdout.writeln('  $path');
    }
    return;
  }

  if (touched.isNotEmpty) {
    fail(
      'Implementation branch changed Coordinator-owned state:\n  '
      '${touched.join('\n  ')}\n'
      'Return a Delivery Note; Coordinator publishes state separately.',
    );
  }
  stdout.writeln(
    'COORDINATOR-STATE-GUARD: PASS (no Coordinator-owned state diff)',
  );
}
