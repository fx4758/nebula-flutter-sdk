import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('PLATFORM-API-GUARD: FAIL — $message');
  exit(1);
}

Map<String, dynamic> loadBoard() {
  final file = File('docs/multi_agent/task_board.json');
  if (!file.existsSync()) fail('task_board.json missing');
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>) fail('task board is not an object');
  return value;
}

bool globMatch(String path, String pattern) {
  final escaped = RegExp.escape(pattern).replaceAll(r'\*', '.*');
  return RegExp('^$escaped\$').hasMatch(path);
}

bool protectedPath(String path, List<String> rules) {
  for (final rule in rules) {
    if (rule.endsWith('/') ? path.startsWith(rule) : path == rule) return true;
  }
  return false;
}

List<String> gitLines(String repo, List<String> args) {
  final result = Process.runSync('git', ['-C', repo, ...args]);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed in $repo: ${result.stderr}'.trim());
  }
  return result.stdout
      .toString()
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

Set<String> changedFiles(String repo, String base) {
  final files = <String>{};
  files.addAll(gitLines(repo, ['diff', '--name-only', '$base...HEAD']));
  files.addAll(gitLines(repo, ['diff', '--name-only']));
  files.addAll(gitLines(repo, ['diff', '--cached', '--name-only']));
  files.addAll(gitLines(repo, ['ls-files', '--others', '--exclude-standard']));
  return files;
}

void validateAuthorization(String id, Map<String, dynamic> data) {
  final mode = data['platform_api_mode'];
  if (mode != 'IMPLEMENT_FROZEN_CONTRACT' && mode != 'CONTRACT_CHANGE') return;
  final auth = data['platform_change_authorization'];
  if (auth is! Map<String, dynamic>)
    fail('$id write mode missing authorization');
  for (final key in [
    'acr_id',
    'acr_path',
    'decision',
    'frozen_contract',
    'backend_baseline_commit',
    'independent_reviewer',
    'adapter_first_analysis'
  ]) {
    if ((auth[key]?.toString() ?? '').isEmpty)
      fail('$id authorization missing $key');
  }
  if (auth['decision'] != 'APPROVED') fail('$id ACR is not APPROVED');
  final acr = File('docs/multi_agent/${auth['acr_path']}');
  if (!acr.existsSync()) fail('$id approved ACR file missing: ${acr.path}');
  if (mode == 'CONTRACT_CHANGE') {
    for (final key in [
      'adr_id',
      'adr_path',
      'contract_version',
      'compatibility_plan',
      'rollback_plan'
    ]) {
      if ((auth[key]?.toString() ?? '').isEmpty)
        fail('$id contract change missing $key');
    }
    final adr = File('docs/multi_agent/${auth['adr_path']}');
    if (!adr.existsSync()) fail('$id ADR file missing: ${adr.path}');
    final consumers = auth['second_consumer_evidence'];
    if (consumers is! List || consumers.length < 2)
      fail('$id contract change needs triggering + second consumer evidence');
    final triggering = auth['triggering_product']?.toString() ?? '';
    final names = consumers
        .whereType<Map<Object?, Object?>>()
        .map((e) => e['consumer']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
    if (triggering.isEmpty || !names.contains(triggering) || names.length < 2) {
      fail(
          '$id evidence must include triggering product and another named consumer');
    }
  }
}

void selfCheck(Map<String, dynamic> board) {
  if (board['schema_version'] != 5) fail('task board schema_version must be 5');
  final policy = board['platform_api_governance'];
  if (policy is! Map<String, dynamic>) fail('platform_api_governance missing');
  final policyPath = policy['policy']?.toString() ?? '';
  if (policyPath.isEmpty || !File('docs/multi_agent/$policyPath').existsSync())
    fail('Platform API policy missing');
  final allowed =
      (policy['allowed_modes'] as List?)?.cast<String>().toSet() ?? <String>{};
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic>) fail('story_tracking missing');
  for (final entry in stories.entries) {
    final id = entry.key;
    final data = entry.value;
    if (data is! Map<String, dynamic>) fail('$id invalid');
    final mode = data['platform_api_mode']?.toString() ?? '';
    final sdkMode = data['sdk_public_api_mode']?.toString() ?? '';
    if (!allowed.contains(mode)) fail('$id invalid platform_api_mode=$mode');
    if (!{'NONE', 'READ_ONLY', 'CHANGE_APPROVED'}.contains(sdkMode))
      fail('$id invalid sdk_public_api_mode=$sdkMode');
    if (data['product_adapter_rule'] != 'ADAPTER_FIRST')
      fail('$id must declare ADAPTER_FIRST');
    validateAuthorization(id, data);
  }
  stdout
      .writeln('PLATFORM-API-GUARD: PASS (policy/schema authorization valid)');
}

void main(List<String> args) {
  final board = loadBoard();
  if (args.contains('--self-check')) return selfCheck(board);
  final i = args.indexOf('--story');
  if (i < 0 || i + 1 >= args.length)
    fail('usage: --story <STORY_ID> [--backend-repo <path>] [--base <commit>]');
  final id = args[i + 1];
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic> || !stories.containsKey(id))
    fail('$id is not registered');
  final data = stories[id] as Map<String, dynamic>;
  validateAuthorization(id, data);
  final mode = data['platform_api_mode']?.toString() ?? '';
  var repo = data['backend_repo']?.toString() ?? '';
  final ri = args.indexOf('--backend-repo');
  if (ri >= 0 && ri + 1 < args.length) repo = args[ri + 1];
  if (mode == 'NONE') {
    stdout.writeln(
        'PLATFORM-API-GUARD: PASS ($id has no Platform API write scope)');
    return;
  }
  if (repo.isEmpty || !Directory(repo).existsSync())
    fail('$id backend repo unavailable: $repo');
  var base = data['backend_baseline_commit']?.toString() ?? '';
  final bi = args.indexOf('--base');
  if (bi >= 0 && bi + 1 < args.length) base = args[bi + 1];
  if (base.isEmpty) fail('$id missing backend_baseline_commit');
  gitLines(repo, ['cat-file', '-e', '$base^{commit}']);
  if (mode == 'READ_ONLY') {
    final policy = board['platform_api_governance'] as Map<String, dynamic>;
    final protected =
        (policy['protected_runtime_config_paths'] as List).cast<String>();
    final exceptions =
        (policy['read_only_test_exceptions'] as List).cast<String>();
    final changed = changedFiles(repo, base).toList()..sort();
    final violations = changed
        .where((p) =>
            protectedPath(p, protected) &&
            !exceptions.any((x) => globMatch(p, x)))
        .toList();
    if (violations.isNotEmpty) {
      fail(
          '$id is READ_ONLY but production Platform surface changed:\n  ${violations.join('\n  ')}\nRaise ACR + separate authorized Story.');
    }
    stdout.writeln(
        'PLATFORM-API-GUARD: PASS ($id READ_ONLY; no protected production diff)');
    return;
  }
  stdout.writeln('PLATFORM-API-GUARD: PASS ($id $mode authorization present)');
}
