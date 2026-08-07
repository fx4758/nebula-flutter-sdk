import 'dart:convert';
import 'dart:io';

typedef FixtureMutation = void Function(Directory root);

final class GuardCase {
  const GuardCase.fail(this.name, this.ruleId, this.mutate)
      : shouldPass = false;

  const GuardCase.pass(this.name, this.mutate)
      : ruleId = null,
        shouldPass = true;

  final String name;
  final String? ruleId;
  final FixtureMutation mutate;
  final bool shouldPass;
}

void main() {
  final Directory sourceRoot = Directory.current.absolute;
  final String guardPath = '${sourceRoot.path}/tool/governance.dart';
  final List<GuardCase> cases = <GuardCase>[
    GuardCase.pass('baseline and safe source examples', (Directory root) {
      _writeSource(
        root,
        'safe_examples.dart',
        "final String appId = 'public-id';\n"
            'void createTask() => nebulaAi.createTask();\n',
      );
    }),
    GuardCase.pass('valid time-bounded exception', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        _validException('EX-VALID'),
      ]);
    }),
    GuardCase.fail('required file', 'GOV-REQUIRED', (Directory root) {
      File('${root.path}/AGENTS.md').deleteSync();
    }),
    GuardCase.fail('AGENTS context budget', 'GOV-CONTEXT', (Directory root) {
      _appendLines(File('${root.path}/AGENTS.md'), 121);
    }),
    GuardCase.fail('handoff context budget', 'GOV-CONTEXT', (Directory root) {
      _appendLines(File('${root.path}/docs/00_AI_HANDOFF.md'), 161);
    }),
    GuardCase.fail('invalid task state', 'GOV-TASK', (Directory root) {
      _breakTaskState(File('${root.path}/docs/STATUS.md'));
    }),
    GuardCase.fail('duplicate task ID', 'GOV-TASK', (Directory root) {
      _duplicateTaskId(File('${root.path}/docs/STATUS.md'));
    }),
    GuardCase.fail('no task rows', 'GOV-TASK', (Directory root) {
      File('${root.path}/docs/STATUS.md').writeAsStringSync(
        '# Execution Status\n\nNo registered task.\n',
      );
    }),
    GuardCase.fail('unreviewed public export', 'API-EXPORT', (Directory root) {
      File('${root.path}/lib/nebula_sdk.dart').writeAsStringSync(
        "export 'src/unreviewed.dart';\n",
        mode: FileMode.append,
      );
    }),
    GuardCase.fail('missing public export', 'API-EXPORT', (Directory root) {
      _replaceInFile(
        File('${root.path}/lib/nebula_sdk.dart'),
        "export 'src/transport.dart';\n",
        '',
      );
    }),
    GuardCase.fail('public API budget', 'API-BUDGET', (Directory root) {
      _editPolicy(root, (Map<String, Object?> policy) {
        final Map<String, Object?> limits =
            (policy['limits']! as Map).cast<String, Object?>();
        limits['max_public_exports'] = 1;
      });
    }),
    GuardCase.fail('Dart file budget', 'ARCH-FILE-BUDGET', (Directory root) {
      _editPolicy(root, (Map<String, Object?> policy) {
        final Map<String, Object?> limits =
            (policy['limits']! as Map).cast<String, Object?>();
        limits['max_dart_file_lines'] = 1;
      });
    }),
    GuardCase.fail('mobile shared secret', 'SEC-MOBILE-SECRET', (
      Directory root,
    ) {
      _writeSource(
          root, 'secret_probe.dart', 'final String appSecret = value;');
    }),
    GuardCase.fail('client credentials grant', 'SEC-CLIENT-CREDENTIALS', (
      Directory root,
    ) {
      _writeSource(
        root,
        'grant_probe.dart',
        "final String grant = 'client_credentials';",
      );
    }),
    GuardCase.fail('direct provider call', 'ARCH-DIRECT-PROVIDER', (
      Directory root,
    ) {
      _writeSource(
          root, 'provider_probe.dart', 'void call() => openai.send();');
    }),
    GuardCase.fail('body-authored app scope', 'DATA-TRUST-BODY-APP-ID', (
      Directory root,
    ) {
      _writeSource(root, 'scope_probe.dart', "final body = {'app_id': appId};");
    }),
    GuardCase.fail('policy positive example', 'GOV-POLICY', (Directory root) {
      _editPolicy(root, (Map<String, Object?> policy) {
        final List<Object?> patterns =
            policy['forbidden_source_patterns']! as List<Object?>;
        final Map<String, Object?> first =
            (patterns.first! as Map).cast<String, Object?>();
        first['examples_match'] = <String>['final String appId;'];
      });
    }),
    GuardCase.fail('invalid policy regex', 'GOV-POLICY', (Directory root) {
      _editPolicy(root, (Map<String, Object?> policy) {
        final List<Object?> patterns =
            policy['forbidden_source_patterns']! as List<Object?>;
        final Map<String, Object?> first =
            (patterns.first! as Map).cast<String, Object?>();
        first['pattern'] = '[';
      });
    }),
    GuardCase.fail('expired exception', 'GOV-EXCEPTION', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        _validException('EX-EXPIRED')..['expires_on'] = '2020-01-01',
      ]);
    }),
    GuardCase.fail('wildcard exception', 'GOV-EXCEPTION', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        _validException('EX-WILDCARD')..['path'] = 'lib/*',
      ]);
    }),
    GuardCase.fail('overlong exception', 'GOV-EXCEPTION', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        _validException('EX-OVERLONG')..['expires_on'] = '2099-01-01',
      ]);
    }),
    GuardCase.fail('incomplete exception', 'GOV-EXCEPTION', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        <String, Object?>{'id': 'EX-INCOMPLETE'},
      ]);
    }),
    GuardCase.fail('duplicate exception', 'GOV-EXCEPTION', (Directory root) {
      _writeExceptions(root, <Map<String, Object?>>[
        _validException('EX-DUPLICATE'),
        _validException('EX-DUPLICATE'),
      ]);
    }),
    GuardCase.fail(
      'public API surface drift',
      'API-SURFACE',
      (Directory root) {
        File('${root.path}/lib/src/capabilities.dart').writeAsStringSync(
          '\nfinal class SurfaceDriftProbe {}\n',
          mode: FileMode.append,
        );
      },
    ),
    // 回归：注释/字符串里的路径通配符 `/*` 不得被 comment stripper 误判为块注释
    // 开头。误判会吞掉其后全部声明，表现为 API-SURFACE 假报 "removed symbol"。
    GuardCase.pass('path wildcard in comments and strings', (Directory root) {
      _prependSource(
        File('${root.path}/lib/src/capabilities.dart'),
        '// Mobile auth endpoints live under `/api/v1/mobile/auth/*` '
        '(ADR-F008);\n'
        '// the legacy `/api/v1/auth/*` prefix is reserved.\n'
        '/// Doc-comment form must behave identically: `/api/v1/**/*`.\n'
        "final String _pathWildcardProbe = '/api/v1/mobile/auth/*';\n"
        "final String _blockLikeProbe = '/* still a string */';\n",
      );
    }),
    GuardCase.fail('hard-coded credential value', 'SEC-SCAN', (Directory root) {
      // 反例密钥拆开拼接：源码字面量不得构成完整密钥（否则扫描器命中自身）。
      final String fakeAwsKey = 'AKIA${'IOSFODNN7EXAMPLE'}';
      _writeSource(
        root,
        'leak_probe.dart',
        "final String awsKey = '$fakeAwsKey';",
      );
    }),
  ];

  final List<String> failures = <String>[];
  final Stopwatch suiteWatch = Stopwatch()..start();
  for (final GuardCase testCase in cases) {
    final Directory fixture = Directory.systemTemp.createTempSync(
      'nebula-governance-',
    );
    try {
      _copyTree(sourceRoot, fixture);
      testCase.mutate(fixture);
      final ProcessResult result = Process.runSync(
        Platform.resolvedExecutable,
        <String>[guardPath],
        workingDirectory: fixture.path,
      );
      final String output = '${result.stdout}\n${result.stderr}';
      final bool exitMatches =
          testCase.shouldPass ? result.exitCode == 0 : result.exitCode != 0;
      final bool ruleMatches =
          testCase.ruleId == null || output.contains('[${testCase.ruleId}]');
      if (!exitMatches || !ruleMatches) {
        failures.add(
          '${testCase.name}: exit=${result.exitCode}, '
          'expected=${testCase.shouldPass ? 'PASS' : testCase.ruleId}\n$output',
        );
      } else {
        stdout.writeln('PASS ${testCase.name}');
      }
    } finally {
      fixture.deleteSync(recursive: true);
    }
  }
  suiteWatch.stop();

  if (failures.isNotEmpty) {
    stderr.writeln('\nGovernance regression: FAIL (${failures.length})');
    for (final String failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Governance regression: PASS '
    '(${cases.length} cases, ${suiteWatch.elapsedMilliseconds}ms)',
  );
}

void _copyTree(Directory source, Directory destination) {
  const Set<String> skipped = <String>{'.git', '.dart_tool', 'build'};
  for (final FileSystemEntity entity in source.listSync(followLinks: false)) {
    final String name = entity.uri.pathSegments
        .where((String segment) => segment.isNotEmpty)
        .last;
    if (skipped.contains(name)) continue;
    final String targetPath = '${destination.path}/$name';
    if (entity is Directory) {
      final Directory target = Directory(targetPath)..createSync();
      _copyTree(entity, target);
    } else if (entity is File) {
      entity.copySync(targetPath);
    }
  }
}

void _appendLines(File file, int count) {
  file.writeAsStringSync(
    List<String>.filled(count, 'context budget probe').join('\n'),
    mode: FileMode.append,
  );
}

void _replaceInFile(File file, String from, String to) {
  final String original = file.readAsStringSync();
  if (!original.contains(from)) {
    throw StateError('fixture text not found: $from');
  }
  file.writeAsStringSync(original.replaceFirst(from, to));
}

/// 把 STATUS.md 中第一条任务行的状态改成非法状态，触发 GOV-TASK；
/// 若文件里没有任何任务行，则插入一条带非法状态的 fixture 任务。
/// 与 tool/governance.dart 的 taskRow 正则保持一致，不依赖具体任务 ID。
void _breakTaskState(File status) {
  final RegExp taskRow = RegExp(
    r'^(\|\s*[A-Z][A-Z0-9]*-[^| ]+\s*\|\s*)([A-Z_]+)(\s*\|)',
  );
  final List<String> lines = status.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? match = taskRow.firstMatch(lines[i]);
    if (match != null) {
      lines[i] = '${match.group(1)}ALMOST${match.group(3)}';
      status.writeAsStringSync('${lines.join('\n')}\n');
      return;
    }
  }
  status.writeAsStringSync(
    '# Execution Status\n\n| GX-FIXTURE | ALMOST | - | regression fixture |\n',
  );
}

/// 把 STATUS.md 中第一条任务行的 ID 复制出一行重复任务，触发 GOV-TASK；
/// 若文件里没有任何任务行，则插入两条相同 ID 的 fixture 任务。
void _duplicateTaskId(File status) {
  final RegExp taskRow = RegExp(
    r'^\|\s*([A-Z][A-Z0-9]*-[^| ]+)\s*\|\s*([A-Z_]+)\s*\|',
  );
  for (final String line in status.readAsLinesSync()) {
    final RegExpMatch? match = taskRow.firstMatch(line);
    if (match != null) {
      status.writeAsStringSync(
        '\n| ${match.group(1)} | READY | duplicate | probe |\n',
        mode: FileMode.append,
      );
      return;
    }
  }
  status.writeAsStringSync(
    '# Execution Status\n\n'
    '| GX-FIXTURE | READY | a | probe |\n'
    '| GX-FIXTURE | READY | b | probe |\n',
  );
}

void _writeSource(Directory root, String name, String contents) {
  File('${root.path}/lib/src/$name').writeAsStringSync('$contents\n');
}

/// 在已导出源文件顶部插入 [prefix]，使其后的既有声明成为“可被吞掉”的目标。
void _prependSource(File file, String prefix) {
  if (!file.existsSync()) {
    throw StateError('fixture source not found: ${file.path}');
  }
  file.writeAsStringSync('$prefix${file.readAsStringSync()}');
}

void _editPolicy(
  Directory root,
  void Function(Map<String, Object?> policy) edit,
) {
  final File file = File('${root.path}/governance/policy.json');
  final Map<String, Object?> policy =
      (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  edit(policy);
  file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(policy)}\n');
}

Map<String, Object?> _validException(String id) => <String, Object?>{
      'id': id,
      'rule_id': 'SEC-MOBILE-SECRET',
      'path': 'lib/src/example.dart',
      'owner': 'governance-test',
      'reason': 'regression fixture',
      'issue': 'G0-02',
      'expires_on': _dateAfter(days: 10),
    };

String _dateAfter({required int days}) {
  final DateTime date = DateTime.now().toUtc().add(Duration(days: days));
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void _writeExceptions(
  Directory root,
  List<Map<String, Object?>> exceptions,
) {
  final File file = File('${root.path}/governance/exceptions.json');
  final Map<String, Object?> registry = <String, Object?>{
    'schema_version': 1,
    'exceptions': exceptions,
  };
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(registry)}\n',
  );
}
