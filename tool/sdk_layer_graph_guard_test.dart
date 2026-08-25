import 'dart:io';

import 'sdk_layer_graph_guard.dart' as guard;

void _expect(bool condition, String message) {
  if (!condition) {
    stderr.writeln('FAIL $message');
    exitCode = 1;
    throw StateError(message);
  }
  stdout.writeln('PASS $message');
}

void _copyTree(Directory source, Directory destination) {
  for (final FileSystemEntity entity in source.listSync(followLinks: false)) {
    final String name =
        entity.uri.pathSegments.where((String part) => part.isNotEmpty).last;
    final String target = '${destination.path}/$name';
    if (entity is Directory) {
      final Directory out = Directory(target)..createSync();
      _copyTree(entity, out);
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

Directory _fixture(Directory sourceRoot) {
  final Directory root =
      Directory.systemTemp.createTempSync('nebula-layer-guard-');
  Directory('${root.path}/governance').createSync(recursive: true);
  File('${sourceRoot.path}/governance/sdk_boundary_policy.json').copySync(
    '${root.path}/governance/sdk_boundary_policy.json',
  );
  final Directory libSrc = Directory('${root.path}/lib/src')
    ..createSync(recursive: true);
  _copyTree(Directory('${sourceRoot.path}/lib/src'), libSrc);
  return root;
}

void _append(Directory root, String relative, String line) {
  File('${root.path}/$relative')
      .writeAsStringSync('\n$line\n', mode: FileMode.append);
}

void _expectRule(
  Directory root,
  String ruleId,
  String label,
) {
  final List<guard.LayerGraphFinding> findings = guard.checkSdkLayerGraph(root);
  _expect(
    findings.any((guard.LayerGraphFinding item) => item.ruleId == ruleId),
    '$label -> $ruleId',
  );
}

void main() {
  final Directory sourceRoot = Directory.current.absolute;
  _expect(guard.checkSdkLayerGraph(sourceRoot).isEmpty,
      'canonical baseline has zero layer findings');

  final List<void Function()> cases = <void Function()>[
    () {
      final Directory root = _fixture(sourceRoot);
      try {
        _append(root, 'lib/src/transport/proof_headers.dart',
            "import '../auth/session.dart';");
        _expectRule(root, 'ARCH-LAYER-EDGE', 'transport -> auth rejected');
      } finally {
        root.deleteSync(recursive: true);
      }
    },
    () {
      final Directory root = _fixture(sourceRoot);
      try {
        _append(root, 'lib/src/analytics/event.dart',
            "import '../error_reporting/report.dart';");
        _expectRule(
            root, 'ARCH-LAYER-EDGE', 'sibling capability edge rejected');
      } finally {
        root.deleteSync(recursive: true);
      }
    },
    () {
      final Directory root = _fixture(sourceRoot);
      try {
        _append(root, 'lib/src/foundation/errors.dart',
            "import '../transport.dart';");
        _expectRule(
            root, 'ARCH-LAYER-EDGE', 'foundation -> transport rejected');
      } finally {
        root.deleteSync(recursive: true);
      }
    },
    () {
      final Directory root = _fixture(sourceRoot);
      try {
        _append(root, 'lib/src/auth/session.dart',
            "import '../testing/fake_transport.dart';");
        _expectRule(root, 'ARCH-LAYER-EDGE', 'production -> testing rejected');
      } finally {
        root.deleteSync(recursive: true);
      }
    },
    () {
      final Directory root = _fixture(sourceRoot);
      try {
        final File file = File('${root.path}/lib/src/feature/probe.dart');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('final class Probe {}\n');
        _expectRule(
            root, 'ARCH-LAYER-UNCLASSIFIED', 'unclassified module rejected');
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  ];
  for (final void Function() testCase in cases) {
    testCase();
  }
  stdout.writeln(
      'SDK Layer Graph Guard regression: PASS (${cases.length + 1} cases)');
}
