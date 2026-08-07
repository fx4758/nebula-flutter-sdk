import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('COORDINATOR-STATE-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> loadBoard() {
  final f = File('docs/multi_agent/task_board.json');
  if (!f.existsSync()) fail('task_board.json missing');
  final v = jsonDecode(f.readAsStringSync());
  if (v is! Map<String, dynamic>) fail('task board invalid');
  return v;
}

List<String> protectedPaths(Map<String, dynamic> board) {
  final cross = board['cross_repo_governance'];
  if (cross is! Map<String, dynamic>) fail('cross_repo_governance missing');
  final paths = cross['coordinator_owned_paths'];
  if (paths is! List || paths.isEmpty) fail('coordinator_owned_paths missing');
  return paths.cast<String>();
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

Set<String> changes(String repo, String base) {
  final out = <String>{};
  out.addAll(gitLines(repo, ['diff', '--name-only', '$base...HEAD']));
  out.addAll(gitLines(repo, ['diff', '--name-only']));
  out.addAll(gitLines(repo, ['diff', '--cached', '--name-only']));
  out.addAll(gitLines(repo, ['ls-files', '--others', '--exclude-standard']));
  return out;
}

void main(List<String> args) {
  final board = loadBoard();
  final protected = protectedPaths(board);
  if (args.contains('--self-check')) {
    stdout.writeln(
        'COORDINATOR-STATE-GUARD: PASS (${protected.length} protected paths)');
    return;
  }
  if (args.contains('--coordinator')) {
    stdout.writeln(
        'COORDINATOR-STATE-GUARD: PASS (explicit Coordinator operation)');
    return;
  }
  var repo = Directory.current.path;
  final ri = args.indexOf('--repo');
  if (ri >= 0 && ri + 1 < args.length) repo = args[ri + 1];
  final bi = args.indexOf('--base');
  if (bi < 0 || bi + 1 >= args.length)
    fail('usage: --base <commit> [--repo <path>]');
  final base = args[bi + 1];
  gitLines(repo, ['cat-file', '-e', '$base^{commit}']);
  final touched = changes(repo, base).where(protected.contains).toList()
    ..sort();
  if (touched.isNotEmpty) {
    fail(
        'Implementation branch changed Coordinator-owned state:\n  ${touched.join('\n  ')}\nReturn a Delivery Note; Coordinator updates state separately.');
  }
  stdout.writeln(
      'COORDINATOR-STATE-GUARD: PASS (no Coordinator-owned state diff)');
}
