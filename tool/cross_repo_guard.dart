import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('CROSS-REPO-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> loadBoard() {
  final f = File('docs/multi_agent/task_board.json');
  if (!f.existsSync())
    fail('task_board.json missing; run from governance repo');
  final v = jsonDecode(f.readAsStringSync());
  if (v is! Map<String, dynamic>) fail('task board invalid');
  return v;
}

String gitCommonDir(String path) {
  final r = Process.runSync('git', [
    '-C',
    path,
    'rev-parse',
    '--path-format=absolute',
    '--git-common-dir',
  ]);
  if (r.exitCode != 0) fail('not a Git execution repo: $path');
  return Directory(r.stdout.toString().trim())
      .absolute
      .resolveSymbolicLinksSync();
}

void selfCheck(Map<String, dynamic> board) {
  if (board['schema_version'] != 5) fail('Task Board schema must be V5');
  final cross = board['cross_repo_governance'];
  if (cross is! Map<String, dynamic>) fail('cross_repo_governance missing');
  if (cross['state_write_authority'] != 'COORDINATOR_ONLY')
    fail('state authority not coordinator-only');
  if (cross['implementation_agent_task_board_write'] != false)
    fail('Agent task-board write must be false');
  if (cross['one_execution_repo_per_story'] != true)
    fail('one execution repo rule missing');
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic>) fail('story_tracking missing');
  for (final e in stories.entries) {
    final id = e.key;
    final d = e.value;
    if (d is! Map<String, dynamic>) fail('$id invalid');
    for (final k in [
      'execution_repo',
      'execution_branch',
      'execution_remote',
      'state_write_authority',
      'agent_may_edit_task_board'
    ]) {
      if (!d.containsKey(k)) fail('$id missing $k');
    }
    if (d['state_write_authority'] != 'COORDINATOR_ONLY')
      fail('$id may not own persisted state');
    if (d['agent_may_edit_task_board'] != false)
      fail('$id illegally allows task-board writes');
    final branch = d['execution_branch'].toString();
    if (branch == 'main' || branch == 'dev' || branch.startsWith('release/'))
      fail('$id uses shared branch $branch');
  }
  stdout.writeln(
      'CROSS-REPO-GUARD: PASS (${stories.length} Stories; one execution repo each)');
}

void main(List<String> args) {
  final board = loadBoard();
  if (args.contains('--self-check')) return selfCheck(board);
  final si = args.indexOf('--story');
  final ri = args.indexOf('--repo');
  if (si < 0 || si + 1 >= args.length || ri < 0 || ri + 1 >= args.length) {
    fail('usage: --story <ID> --repo <execution_repo> [--check-branch]');
  }
  final id = args[si + 1];
  final suppliedRepo = args[ri + 1];
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic> || !stories.containsKey(id))
    fail('$id not registered');
  final d = stories[id] as Map<String, dynamic>;
  if (d['agent_may_edit_task_board'] != false)
    fail('$id illegally allows task-board writes');
  final expectedRaw = d['execution_repo'].toString();
  final governanceRoot = Directory.current.absolute.path;
  final expectedPath =
      expectedRaw == '.' ? governanceRoot : '$governanceRoot/$expectedRaw';
  final expectedCommon = gitCommonDir(expectedPath);
  final suppliedCommon = gitCommonDir(suppliedRepo);
  if (suppliedCommon != expectedCommon) {
    fail(
        '$id execution repo mismatch:\n  expected=$expectedPath\n  supplied=$suppliedRepo\nDo not modify a second repository; request a new Story.');
  }
  final expectedBranch = d['execution_branch'].toString();
  if (args.contains('--check-branch')) {
    final r = Process.runSync(
        'git', ['-C', suppliedRepo, 'branch', '--show-current']);
    if (r.exitCode != 0) fail('cannot read execution branch: ${r.stderr}');
    final actual = r.stdout.toString().trim();
    if (actual != expectedBranch)
      fail('$id branch mismatch: expected=$expectedBranch actual=$actual');
  }
  stdout.writeln('CROSS-REPO-GUARD: PASS');
  stdout.writeln('execution_repo=$expectedPath');
  stdout.writeln('execution_branch=$expectedBranch');
  stdout.writeln('governance_state=READ_ONLY_FOR_IMPLEMENTATION_AGENT');
}
