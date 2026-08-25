import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'sdk_release_gate.dart' as gate;

const commit = '0123456789abcdef0123456789abcdef01234567';
const rc1Commit = '64df49af6ff7554da94d5fa2ebaef27bdba35465';

Map<String, dynamic> policy() => <String, dynamic>{
      'schema_version': 2,
      'tag_prefix': 'v',
      'channels': <String, dynamic>{
        'beta': <String, dynamic>{'prerelease_prefix': 'rc'},
      },
    };

Map<String, dynamic> releaseStory(
  String id, {
  required String version,
  required String tag,
  String? branch,
}) =>
    <String, dynamic>{
      'status': 'READY',
      'platform_api_mode': 'NONE',
      'sdk_public_api_mode': 'READ_ONLY',
      'state_write_authority': 'COORDINATOR_ONLY',
      'agent_may_edit_task_board': false,
      'implementation_authorized': true,
      'release_packaging_authorized': true,
      'tag_publication_authorized': true,
      'execution_repo': '.',
      'execution_branch': branch ?? 'sdk-release/$id',
      'task_pack': 'task_packs/$id.md',
      'expected_version': version,
      'expected_tag': tag,
    };

String packFor(String id, String branch) => '''
# $id
- ID：$id
- Execution branch：`$branch`
''';

void main() {
  test('policy freezes distribution modes without a hard-coded release Story',
      () {
    final value =
        (jsonDecode(File(gate.releasePolicyPath).readAsStringSync()) as Map)
            .cast<String, dynamic>();
    final channels = (value['channels'] as Map).cast<String, dynamic>();
    expect(value['schema_version'], 2);
    expect(value.containsKey('release_workflow_story'), isFalse);
    expect((channels['dev'] as Map)['distribution'], 'path');
    expect((channels['beta'] as Map)['distribution'], 'git_tag');
    expect((channels['production'] as Map)['distribution'], 'registry');
  });

  test('beta accepts immutable rc metadata', () {
    final findings = gate.validateReleaseMetadata(
      const gate.ReleaseMetadata(
        channel: 'beta',
        version: '0.1.0-rc2',
        publishTo: 'none',
        tag: 'v0.1.0-rc2',
        approvedCommit: commit,
        headCommit: commit,
        tagCommit: commit,
      ),
      policy(),
    );
    expect(findings, isEmpty);
  });

  test('beta rejects dev version and retargeted tag', () {
    final findings = gate.validateReleaseMetadata(
      const gate.ReleaseMetadata(
        channel: 'beta',
        version: '0.1.0-dev.1',
        publishTo: 'none',
        tag: 'v0.1.0-dev.1',
        approvedCommit: commit,
        headCommit: commit,
        tagCommit: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      policy(),
    );
    expect(findings.any((e) => e.contains('must start with rc')), isTrue);
    expect(findings.any((e) => e.contains('tag must resolve to HEAD')), isTrue);
  });

  test('production requires stable version and HTTPS registry', () {
    final accepted = gate.validateReleaseMetadata(
      const gate.ReleaseMetadata(
        channel: 'production',
        version: '0.1.0',
        publishTo: 'https://packages.example.test/dart',
        tag: 'v0.1.0',
        approvedCommit: commit,
        headCommit: commit,
        tagCommit: commit,
      ),
      policy(),
    );
    expect(accepted, isEmpty);

    final rejected = gate.validateReleaseMetadata(
      const gate.ReleaseMetadata(
        channel: 'production',
        version: '0.1.0-rc2',
        publishTo: 'none',
        tag: 'v0.1.0-rc2',
        approvedCommit: commit,
        headCommit: commit,
        tagCommit: commit,
      ),
      policy(),
    );
    expect(rejected.any((e) => e.contains('stable SemVer')), isTrue);
    expect(rejected.any((e) => e.contains('explicit registry')), isTrue);
  });

  test('resolver binds version and tag to exactly one release Story', () {
    final board = <String, dynamic>{
      'story_tracking': <String, dynamic>{
        'RELEASE-A': releaseStory(
          'RELEASE-A',
          version: '0.1.0-rc1',
          tag: 'v0.1.0-rc1',
        ),
        'RELEASE-B': releaseStory(
          'RELEASE-B',
          version: '0.1.0-rc2',
          tag: 'v0.1.0-rc2',
        ),
      },
    };
    final resolved = gate.resolveReleaseStoryAuthority(
      board,
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
    );
    expect(resolved.findings, isEmpty);
    expect(resolved.id, 'RELEASE-B');
  });

  test('resolver rejects missing and duplicate release authority', () {
    final one = releaseStory(
      'RELEASE-A',
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
    );
    final missing = gate.resolveReleaseStoryAuthority(
      <String, dynamic>{
        'story_tracking': <String, dynamic>{'RELEASE-A': one}
      },
      version: '0.1.0-rc3',
      tag: 'v0.1.0-rc3',
    );
    expect(missing.findings.single, contains('no release Story'));

    final duplicate = gate.resolveReleaseStoryAuthority(
      <String, dynamic>{
        'story_tracking': <String, dynamic>{
          'RELEASE-A': one,
          'RELEASE-B': Map<String, dynamic>.from(one),
        },
      },
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
    );
    expect(duplicate.findings.single, contains('multiple release Stories'));
  });

  test('canonical historical RC1 release Story remains valid', () {
    final board =
        (jsonDecode(File(gate.taskBoardPath).readAsStringSync()) as Map)
            .cast<String, dynamic>();
    final resolved = gate.resolveReleaseStoryAuthority(
      board,
      version: '0.1.0-rc1',
      tag: 'v0.1.0-rc1',
    );
    expect(resolved.findings, isEmpty);
    expect(resolved.id, 'NEBULA-SDK-RELEASE-001');
    final story = resolved.story!;
    final pack =
        File('docs/multi_agent/${story['task_pack']}').readAsStringSync();
    expect(
      gate.validateReleaseStoryAuthority(
        resolved.id!,
        story,
        pack,
        headCommit: rc1Commit,
        tagCommit: rc1Commit,
      ),
      isEmpty,
    );
  });

  test('historical release metadata commit drift fails closed', () {
    final board =
        (jsonDecode(File(gate.taskBoardPath).readAsStringSync()) as Map)
            .cast<String, dynamic>();
    final resolved = gate.resolveReleaseStoryAuthority(
      board,
      version: '0.1.0-rc1',
      tag: 'v0.1.0-rc1',
    );
    expect(resolved.findings, isEmpty);
    final story = Map<String, dynamic>.from(resolved.story!);
    story['release_tag_commit'] = commit;
    final pack =
        File('docs/multi_agent/${story['task_pack']}').readAsStringSync();

    final findings = gate.validateReleaseStoryAuthority(
      resolved.id!,
      story,
      pack,
      headCommit: rc1Commit,
      tagCommit: rc1Commit,
    );

    expect(
      findings.any((e) => e.contains('historical release tag commit drift')),
      isTrue,
    );
  });

  test('authorized release Story accepts its own task-pack branch', () {
    const id = 'RELEASE-B';
    final story = releaseStory(
      id,
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
    );
    expect(
      gate.validateReleaseStoryAuthority(
        id,
        story,
        packFor(id, story['execution_branch'] as String),
        headCommit: commit,
        tagCommit: commit,
      ),
      isEmpty,
    );
  });

  test('revoked release authority fails closed', () {
    const id = 'RELEASE-B';
    final story = releaseStory(
      id,
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
    );
    story['release_packaging_authorized'] = false;
    story['tag_publication_authorized'] = false;
    final findings = gate.validateReleaseStoryAuthority(
      id,
      story,
      packFor(id, story['execution_branch'] as String),
      headCommit: commit,
      tagCommit: commit,
    );
    expect(
        findings.any((e) => e.contains('packaging authority revoked')), isTrue);
    expect(
        findings.any((e) => e.contains('tag publication authority')), isTrue);
  });

  test('branch, Platform and API authority drift remain blocking', () {
    const id = 'RELEASE-B';
    final story = releaseStory(
      id,
      version: '0.1.0-rc2',
      tag: 'v0.1.0-rc2',
      branch: 'sdk-release/reviewed',
    );
    story['platform_api_mode'] = 'READ_ONLY';
    story['sdk_public_api_mode'] = 'CONTRACT_CHANGE';
    final findings = gate.validateReleaseStoryAuthority(
      id,
      story,
      packFor(id, 'sdk-release/drifted'),
      headCommit: commit,
      tagCommit: commit,
    );
    expect(findings.any((e) => e.contains('Platform API mode')), isTrue);
    expect(findings.any((e) => e.contains('SDK public API mode')), isTrue);
    expect(
        findings.any((e) => e.contains('execution branch disagrees')), isTrue);
  });

  test('release workflow remains tag-only and executes the single release gate',
      () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    expect(workflow, contains('tags:'));
    expect(workflow, contains("- 'v*'"));
    expect(workflow, contains('runs-on: nebula-sdk'));
    expect(workflow, contains('tool/sdk_release_gate.dart'));
    expect(workflow, contains('tool/api_surface.dart'));
    expect(workflow, contains('tool/ci_dependency_guard.dart'));
    expect(workflow, isNot(contains('release_workflow_story')));
    expect(workflow, isNot(contains('dart pub publish')));
    expect(workflow, isNot(contains('pub publish')));
  });
}
