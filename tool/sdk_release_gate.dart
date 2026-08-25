import 'dart:convert';
import 'dart:io';

const releasePolicyPath = 'governance/sdk_release_policy.json';
const taskBoardPath = 'docs/multi_agent/task_board.json';

final _fullCommit = RegExp(r'^[0-9a-f]{40}$');
final _stableSemVer = RegExp(r'^\d+\.\d+\.\d+$');
final _preSemVer = RegExp(r'^\d+\.\d+\.\d+-([0-9A-Za-z][0-9A-Za-z.-]*)$');
final _packBranch = RegExp(r'Execution branch：`([^`]+)`');

Never fail(String message) {
  stderr.writeln('SDK-RELEASE-GATE: FAIL — $message');
  exit(1);
}

final class ReleaseMetadata {
  const ReleaseMetadata({
    required this.channel,
    required this.version,
    required this.publishTo,
    required this.tag,
    required this.approvedCommit,
    required this.headCommit,
    required this.tagCommit,
  });
  final String channel;
  final String version;
  final String publishTo;
  final String tag;
  final String approvedCommit;
  final String headCommit;
  final String tagCommit;
}

final class ReleaseStoryResolution {
  const ReleaseStoryResolution({this.id, this.story, required this.findings});
  final String? id;
  final Map<String, dynamic>? story;
  final List<String> findings;
}

List<String> validateReleaseMetadata(
  ReleaseMetadata value,
  Map<String, dynamic> policy,
) {
  final findings = <String>[];
  if (policy['schema_version'] != 2) {
    return ['unsupported release policy schema'];
  }
  final prefix = policy['tag_prefix']?.toString() ?? '';
  final expectedTag = '$prefix${value.version}';
  if (prefix.isEmpty) findings.add('tag_prefix missing');
  if (value.tag != expectedTag) {
    findings.add('tag ${value.tag} must equal $expectedTag');
  }
  if (!_fullCommit.hasMatch(value.approvedCommit)) {
    findings.add('approved commit must be a 40-char lowercase SHA');
  }
  if (value.approvedCommit != value.headCommit) {
    findings.add('HEAD must equal the approved commit');
  }
  if (value.tagCommit != value.headCommit) {
    findings.add('tag must resolve to HEAD');
  }

  if (value.channel == 'beta') {
    final match = _preSemVer.firstMatch(value.version);
    if (match == null) {
      findings.add('beta version must be prerelease SemVer');
    } else {
      final channels = (policy['channels'] as Map?)?.cast<String, dynamic>();
      final beta = (channels?['beta'] as Map?)?.cast<String, dynamic>();
      final rcPrefix = beta?['prerelease_prefix']?.toString() ?? '';
      if (rcPrefix.isEmpty || !match.group(1)!.startsWith(rcPrefix)) {
        findings.add('beta prerelease must start with $rcPrefix');
      }
    }
    if (value.publishTo != 'none') {
      findings.add('beta Git-tag distribution requires publish_to: none');
    }
  } else if (value.channel == 'production') {
    if (!_stableSemVer.hasMatch(value.version)) {
      findings.add('production version must be stable SemVer');
    }
    if (value.publishTo == 'none') {
      findings.add('production requires an explicit registry publish_to');
    } else {
      final uri = Uri.tryParse(value.publishTo);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        findings.add('production registry must be an HTTPS URI');
      }
    }
  } else {
    findings.add('release channel must be beta or production');
  }
  return findings;
}

ReleaseStoryResolution resolveReleaseStoryAuthority(
  Map<String, dynamic> board, {
  required String version,
  required String tag,
}) {
  final stories = board['story_tracking'];
  if (stories is! Map<String, dynamic>) {
    return const ReleaseStoryResolution(
        findings: ['task board story_tracking missing']);
  }
  final matches = <MapEntry<String, Map<String, dynamic>>>[];
  for (final entry in stories.entries) {
    final raw = entry.value;
    if (raw is! Map) continue;
    final story = raw.cast<String, dynamic>();
    if (story['expected_version'] == version && story['expected_tag'] == tag) {
      matches.add(MapEntry(entry.key, story));
    }
  }
  if (matches.isEmpty) {
    return ReleaseStoryResolution(
      findings: ['no release Story matches version=$version tag=$tag'],
    );
  }
  if (matches.length != 1) {
    return ReleaseStoryResolution(
      findings: [
        'multiple release Stories match version=$version tag=$tag: ${matches.map((e) => e.key).join(', ')}'
      ],
    );
  }
  return ReleaseStoryResolution(
    id: matches.single.key,
    story: matches.single.value,
    findings: const [],
  );
}

List<String> validateReleaseStoryAuthority(
  String id,
  Map<String, dynamic> story,
  String taskPackText, {
  required String headCommit,
  required String tagCommit,
}) {
  final findings = <String>[];
  final status = story['status']?.toString();
  final historical =
      status == 'DONE' && story['execution_gate'] == 'CLOSED_RELEASE_PASS';
  final active = {'READY', 'IN_PROGRESS'}.contains(status);
  if (!active && !historical) {
    findings.add('$id release Story is neither active nor a closed release');
  }
  if (story['platform_api_mode'] != 'NONE') {
    findings.add('$id Platform API mode must remain NONE');
  }
  if (story['sdk_public_api_mode'] != 'READ_ONLY') {
    findings.add('$id SDK public API mode must remain READ_ONLY');
  }
  if (story['state_write_authority'] != 'COORDINATOR_ONLY') {
    findings.add('$id state write authority must be COORDINATOR_ONLY');
  }
  if (story['agent_may_edit_task_board'] != false) {
    findings.add('$id implementation agent must not edit Task Board');
  }

  if (active) {
    if (story['implementation_authorized'] != true) {
      findings.add('$id implementation authority revoked');
    }
    if (story['release_packaging_authorized'] != true) {
      findings.add('$id release packaging authority revoked');
    }
    if (story['tag_publication_authorized'] != true) {
      findings.add('$id tag publication authority missing or revoked');
    }
  }

  final expectedVersion = story['expected_version']?.toString() ?? '';
  final expectedTag = story['expected_tag']?.toString() ?? '';
  if (historical) {
    if (story['release_version'] != expectedVersion) {
      findings.add('$id historical release version drift');
    }
    if (story['release_tag'] != expectedTag) {
      findings.add('$id historical release tag drift');
    }
    final releaseCommit = story['release_tag_commit']?.toString() ?? '';
    if (!_fullCommit.hasMatch(releaseCommit)) {
      findings.add('$id historical release tag commit missing');
    } else if (releaseCommit != tagCommit || releaseCommit != headCommit) {
      findings.add(
        '$id historical release tag commit drift from current tag/HEAD',
      );
    }
    if ((story['release_gate']?.toString() ?? '').isEmpty) {
      findings.add('$id historical release gate evidence missing');
    }
  }

  if (story['execution_repo'] != '.') {
    findings.add('$id execution repo must remain .');
  }
  final branch = story['execution_branch']?.toString() ?? '';
  if (branch.isEmpty) findings.add('$id execution branch missing');
  final taskPack = story['task_pack']?.toString() ?? '';
  if (taskPack.isEmpty) findings.add('$id task pack missing');
  if (!taskPackText.contains('ID：$id')) {
    findings.add('$id task pack identity drift');
  }
  final packBranch = _packBranch.firstMatch(taskPackText)?.group(1);
  if (packBranch != branch) {
    findings.add('$id execution branch disagrees with task pack');
  }
  return findings;
}

Map<String, String> readPubspec(File file) {
  if (!file.existsSync()) fail('${file.path} missing');
  String? version;
  String? publishTo;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('version:')) {
      version = line.substring('version:'.length).trim();
    } else if (line.startsWith('publish_to:')) {
      publishTo = line.substring('publish_to:'.length).trim();
      final quoted = publishTo.length >= 2 &&
          ((publishTo.startsWith("'") && publishTo.endsWith("'")) ||
              (publishTo.startsWith('\"') && publishTo.endsWith('\"')));
      if (quoted) publishTo = publishTo.substring(1, publishTo.length - 1);
    }
  }
  if (version == null || version.isEmpty) fail('pubspec version missing');
  if (publishTo == null || publishTo.isEmpty) {
    fail('pubspec publish_to missing');
  }
  return {'version': version, 'publish_to': publishTo};
}

String git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr.toString().trim()}');
  }
  return result.stdout.toString().trim();
}

void selfCheck() {
  final policy = <String, dynamic>{
    'schema_version': 2,
    'tag_prefix': 'v',
    'channels': <String, dynamic>{
      'beta': <String, dynamic>{'prerelease_prefix': 'rc'},
    },
  };
  const commit = '0123456789abcdef0123456789abcdef01234567';
  final valid = validateReleaseMetadata(
    const ReleaseMetadata(
      channel: 'beta',
      version: '0.1.0-rc2',
      publishTo: 'none',
      tag: 'v0.1.0-rc2',
      approvedCommit: commit,
      headCommit: commit,
      tagCommit: commit,
    ),
    policy,
  );
  if (valid.isNotEmpty) fail('self-check valid RC: ${valid.join('; ')}');
  final devLeak = validateReleaseMetadata(
    const ReleaseMetadata(
      channel: 'beta',
      version: '0.1.0-dev.1',
      publishTo: 'none',
      tag: 'v0.1.0-dev.1',
      approvedCommit: commit,
      headCommit: commit,
      tagCommit: commit,
    ),
    policy,
  );
  if (!devLeak.any((e) => e.contains('must start with rc'))) {
    fail('self-check must reject dev version on beta channel');
  }
  stdout.writeln('SDK-RELEASE-GATE SELF-CHECK PASS');
}

void main(List<String> args) {
  if (args.contains('--self-check')) return selfCheck();

  String required(String name) {
    final index = args.indexOf(name);
    if (index < 0 || index + 1 >= args.length) {
      fail('missing required argument $name');
    }
    return args[index + 1];
  }

  final channel = required('--channel');
  final approved = required('--approved-commit');
  final tag = required('--tag');
  final root = Directory.current;
  final policyFile = File('${root.path}/$releasePolicyPath');
  final boardFile = File('${root.path}/$taskBoardPath');
  if (!policyFile.existsSync()) fail('$releasePolicyPath missing');
  if (!boardFile.existsSync()) fail('$taskBoardPath missing');
  final policy = (jsonDecode(policyFile.readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final board =
      (jsonDecode(boardFile.readAsStringSync()) as Map).cast<String, dynamic>();
  final pubspec = readPubspec(File('${root.path}/pubspec.yaml'));
  if (git(root, ['status', '--porcelain', '--untracked-files=all'])
      .isNotEmpty) {
    fail('working tree must be clean');
  }
  final head = git(root, ['rev-parse', 'HEAD']);
  final tagCommit = git(root, ['rev-parse', 'refs/tags/$tag^{commit}']);

  final resolution = resolveReleaseStoryAuthority(
    board,
    version: pubspec['version']!,
    tag: tag,
  );
  if (resolution.findings.isNotEmpty) fail(resolution.findings.join('; '));
  final id = resolution.id!;
  final story = resolution.story!;
  final taskPack = story['task_pack']?.toString() ?? '';
  final taskPackFile = File('${root.path}/docs/multi_agent/$taskPack');
  if (!taskPackFile.existsSync()) fail('$id task pack missing: $taskPack');
  final authority = validateReleaseStoryAuthority(
    id,
    story,
    taskPackFile.readAsStringSync(),
    headCommit: head,
    tagCommit: tagCommit,
  );
  if (authority.isNotEmpty) fail(authority.join('; '));

  final findings = validateReleaseMetadata(
    ReleaseMetadata(
      channel: channel,
      version: pubspec['version']!,
      publishTo: pubspec['publish_to']!,
      tag: tag,
      approvedCommit: approved,
      headCommit: head,
      tagCommit: tagCommit,
    ),
    policy,
  );
  if (findings.isNotEmpty) fail(findings.join('; '));

  final api = Process.runSync(
    Platform.resolvedExecutable,
    ['run', 'tool/api_surface.dart'],
    workingDirectory: root.path,
  );
  if (api.exitCode != 0) {
    stderr.write(api.stdout);
    stderr.write(api.stderr);
    fail('API surface snapshot gate failed');
  }
  stdout.writeln(
    'SDK-RELEASE-GATE PASS: story=$id channel=$channel version=${pubspec['version']} tag=$tag commit=$head',
  );
}
