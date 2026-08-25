import 'dart:io';

import 'product_erasure_guard.dart' as guard;

void _expect(bool condition, String label) {
  if (!condition) throw StateError('FAIL $label');
  stdout.writeln('PASS $label');
}

void _copyTree(Directory source, Directory destination) {
  for (final FileSystemEntity entity in source.listSync(followLinks: false)) {
    final String name =
        entity.uri.pathSegments.where((String item) => item.isNotEmpty).last;
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
      Directory.systemTemp.createTempSync('nebula-product-guard-');
  Directory('${root.path}/governance').createSync(recursive: true);
  File('${sourceRoot.path}/governance/sdk_boundary_policy.json').copySync(
    '${root.path}/governance/sdk_boundary_policy.json',
  );
  File('${sourceRoot.path}/pubspec.yaml').copySync('${root.path}/pubspec.yaml');
  final Directory lib = Directory('${root.path}/lib')
    ..createSync(recursive: true);
  _copyTree(Directory('${sourceRoot.path}/lib'), lib);
  return root;
}

void _writeProbe(Directory root, String contents) {
  File('${root.path}/lib/src/foundation/product_guard_probe.dart')
      .writeAsStringSync('$contents\n');
}

void _expectRule(Directory root, String ruleId, String label) {
  final List<guard.ProductErasureFinding> findings =
      guard.checkProductErasure(root);
  _expect(
    findings.any((guard.ProductErasureFinding item) => item.ruleId == ruleId),
    '$label -> $ruleId',
  );
}

void main() {
  final Directory sourceRoot = Directory.current.absolute;
  _expect(
    guard.checkProductErasure(sourceRoot).isEmpty,
    'canonical baseline has zero product-erasure findings',
  );

  final Directory comments = _fixture(sourceRoot);
  try {
    _writeProbe(
      comments,
      '// Nearvia and NFC Writer are consumer examples only.\n'
      '/* Pomodoro belongs to an App, not this SDK. */\n'
      'final String neutralValue = "platform";',
    );
    _expect(
      guard.checkProductErasure(comments).isEmpty,
      'consumer names in comments are ignored',
    );
  } finally {
    comments.deleteSync(recursive: true);
  }

  final List<({String code, String rule, String label})> cases = <({
    String code,
    String rule,
    String label,
  })>[
    (
      code: 'final String product = "Nearvia";',
      rule: 'ARCH-PRODUCT-TOKEN',
      label: 'executable consumer token rejected',
    ),
    (
      code: "import 'package:flutter/widgets.dart';",
      rule: 'ARCH-FLUTTER-COUPLING',
      label: 'Flutter package import rejected',
    ),
    (
      code: 'final Widget productCard = value;',
      rule: 'ARCH-UI-COUPLING',
      label: 'product UI symbol rejected',
    ),
    (
      code: 'final Uri endpoint = Uri.parse("https://product.example.com/v1");',
      rule: 'ARCH-HARDCODED-ORIGIN',
      label: 'hard-coded origin rejected',
    ),
    (
      code: 'final String id = "com.shawn.nfcwriter";',
      rule: 'ARCH-PRODUCT-PACKAGE-ID',
      label: 'consumer package id rejected',
    ),
  ];
  for (final item in cases) {
    final Directory root = _fixture(sourceRoot);
    try {
      _writeProbe(root, item.code);
      _expectRule(root, item.rule, item.label);
    } finally {
      root.deleteSync(recursive: true);
    }
  }

  final Directory dependency = _fixture(sourceRoot);
  try {
    final File pubspec = File('${dependency.path}/pubspec.yaml');
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst(
            'dependencies: {}',
            'dependencies:\n  flutter: any',
          ),
    );
    _expectRule(
      dependency,
      'ARCH-RUNTIME-DEPENDENCY',
      'runtime plugin dependency rejected',
    );
  } finally {
    dependency.deleteSync(recursive: true);
  }

  stdout.writeln(
    'SDK Product-Erasure Guard regression: PASS (${cases.length + 3} cases)',
  );
}
