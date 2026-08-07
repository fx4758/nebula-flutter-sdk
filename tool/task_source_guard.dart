import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('TASK-SOURCE-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> loadBoard() {
  final file = File('docs/multi_agent/task_board.json');
  if (!file.existsSync()) fail('task_board.json missing');
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>) fail('task board is not an object');
  return value;
}

void selfCheck(Map<String, dynamic> board) {
  if (board['execution_ssot'] != true) fail('execution_ssot must be true');
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic> || stories.isEmpty)
    fail('story_tracking missing');
  for (final entry in stories.entries) {
    final id = entry.key;
    final data = entry.value;
    if (data is! Map<String, dynamic>) fail('$id invalid');
    for (final key in [
      'status',
      'owner',
      'reviewer',
      'task_pack',
      'execution_repo',
      'execution_branch',
      'execution_remote',
      'state_write_authority',
      'agent_may_edit_task_board',
      'platform_api_mode',
      'sdk_public_api_mode',
      'product_adapter_rule'
    ]) {
      if ((data[key]?.toString() ?? '').isEmpty) fail('$id missing $key');
    }
    final pack = File('docs/multi_agent/${data['task_pack']}');
    if (!pack.existsSync()) fail('$id task pack missing: ${pack.path}');
    final packText = pack.readAsStringSync();
    if (!packText.contains('ID：$id')) fail('${pack.path} does not declare $id');
    final platformMatch =
        RegExp(r'Platform API mode：.*`([A-Z_]+)`').firstMatch(packText);
    final sdkMatch =
        RegExp(r'SDK public API mode：.*`([A-Z_]+)`').firstMatch(packText);
    final repoMatch = RegExp(r'Execution repo：`([^`]+)`').firstMatch(packText);
    final branchMatch =
        RegExp(r'Execution branch：`([^`]+)`').firstMatch(packText);
    if (platformMatch?.group(1) != data['platform_api_mode']) {
      fail('${pack.path} Platform API mode disagrees with task board');
    }
    if (sdkMatch?.group(1) != data['sdk_public_api_mode']) {
      fail('${pack.path} SDK public API mode disagrees with task board');
    }
    if (repoMatch?.group(1) != data['execution_repo']) {
      fail('${pack.path} execution repo disagrees with task board');
    }
    if (branchMatch?.group(1) != data['execution_branch']) {
      fail('${pack.path} execution branch disagrees with task board');
    }
    if (data['state_write_authority'] != 'COORDINATOR_ONLY') {
      fail('$id state_write_authority must be COORDINATOR_ONLY');
    }
    if (data['agent_may_edit_task_board'] != false) {
      fail('$id implementation Agent must not edit task board');
    }
    final deps = data['depends_on'];
    if (deps is List)
      for (final dep in deps)
        if (!stories.containsKey(dep)) fail('$id unknown dependency $dep');
  }
  if (!File('docs/STATUS.md')
      .readAsStringSync()
      .contains('NON-EXECUTABLE SDK INTERNAL HISTORY'))
    fail('STATUS.md lacks non-executable banner');
  if (!File('docs/00_AI_HANDOFF.md')
      .readAsStringSync()
      .contains('multi_agent/task_board.json'))
    fail('handoff does not route to task board');
  stdout.writeln(
      'TASK-SOURCE-GUARD: PASS (${stories.length} stories; ${board['active_sprint']})');
}

void main(List<String> args) {
  final board = loadBoard();
  if (args.contains('--self-check')) return selfCheck(board);
  final i = args.indexOf('--story');
  if (i < 0 || i + 1 >= args.length) fail('usage: --story <STORY_ID>');
  final id = args[i + 1];
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic> || !stories.containsKey(id))
    fail(
        '$id is not executable; never substitute historical F0/F1/F2/F3/FB/FS/FC work');
  final data = stories[id] as Map<String, dynamic>;
  if (!{'READY', 'IN_PROGRESS'}.contains(data['status']))
    fail('$id status ${data['status']} not executable');
  final deps =
      (data['depends_on'] as List?)?.cast<String>() ?? const <String>[];
  for (final dep in deps) {
    final depData = stories[dep] as Map<String, dynamic>;
    if (depData['status'] != 'DONE')
      fail('$id blocked: $dep is ${depData['status']}');
  }
  stdout.writeln('TASK-SOURCE-GUARD: PASS');
  for (final key in [
    'owner',
    'reviewer',
    'task_pack',
    'execution_repo',
    'execution_branch',
    'execution_remote',
    'state_write_authority',
    'agent_may_edit_task_board',
    'platform_api_mode',
    'sdk_public_api_mode',
    'product_adapter_rule'
  ]) {
    stdout.writeln('$key=${data[key]}');
  }
}
