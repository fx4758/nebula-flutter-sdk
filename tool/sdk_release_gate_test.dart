import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'sdk_release_gate.dart' as gate;

const commit = '0123456789abcdef0123456789abcdef01234567';

Map<String, dynamic> policy() => <String, dynamic>{
      'schema_version': 1,
      'release_workflow_story': 'S1-F03-001',
      'tag_prefix': 'v',
      'channels': <String, dynamic>{
        'beta': <String, dynamic>{'prerelease_prefix': 'rc'},
      },
    };

void main() {
  test('policy freezes dev beta production distribution modes', () {
    final value =
        (jsonDecode(File(gate.releasePolicyPath).readAsStringSync()) as Map)
            .cast<String, dynamic>();
    final channels = (value['channels'] as Map).cast<String, dynamic>();
    expect((channels['dev'] as Map)['distribution'], 'path');
    expect((channels['beta'] as Map)['distribution'], 'git_tag');
    expect((channels['production'] as Map)['distribution'], 'registry');
  });

  test('beta accepts immutable rc metadata', () {
    final findings = gate.validateReleaseMetadata(
      const gate.ReleaseMetadata(
        channel: 'beta',
        version: '0.1.0-rc1',
        publishTo: 'none',
        tag: 'v0.1.0-rc1',
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
        version: '0.1.0-rc1',
        publishTo: 'none',
        tag: 'v0.1.0-rc1',
        approvedCommit: commit,
        headCommit: commit,
        tagCommit: commit,
      ),
      policy(),
    );
    expect(rejected.any((e) => e.contains('stable SemVer')), isTrue);
    expect(rejected.any((e) => e.contains('explicit registry')), isTrue);
  });

  test('release workflow is tag-only and executes release gates', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    expect(workflow, contains("tags:"));
    expect(workflow, contains("- 'v*'"));
    expect(workflow, contains('runs-on: nebula-sdk'));
    expect(workflow, contains('tool/sdk_release_gate.dart'));
    expect(workflow, contains('tool/api_surface.dart'));
    expect(workflow, contains('tool/ci_dependency_guard.dart'));
    expect(workflow, isNot(contains('dart pub publish')));
    expect(workflow, isNot(contains('pub publish')));
  });

  test('story authority remains read-only and Coordinator-owned', () {
    final board = <String, dynamic>{
      'story_tracking': <String, dynamic>{
        'S1-F03-001': <String, dynamic>{
          'platform_api_mode': 'NONE',
          'sdk_public_api_mode': 'READ_ONLY',
          'state_write_authority': 'COORDINATOR_ONLY',
          'agent_may_edit_task_board': false,
          'execution_branch': 's1/f03-001-release',
        },
      },
    };
    expect(gate.validateStoryAuthority(board, policy()), isEmpty);
    final story = (board['story_tracking']
        as Map<String, dynamic>)['S1-F03-001'] as Map<String, dynamic>;
    story['sdk_public_api_mode'] = 'CONTRACT_CHANGE';
    expect(
      gate.validateStoryAuthority(board, policy()).any(
            (e) => e.contains('SDK public API mode must remain READ_ONLY'),
          ),
      isTrue,
    );
  });
}
