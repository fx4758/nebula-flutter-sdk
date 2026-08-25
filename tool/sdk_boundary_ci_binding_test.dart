import 'dart:io';

Never fail(String message) {
  stderr.writeln('FAIL $message');
  exit(1);
}

void expect(bool condition, String label) {
  if (!condition) fail(label);
  stdout.writeln('PASS $label');
}

void main() {
  final File governanceWorkflow = File('.github/workflows/governance.yml');
  final File releaseWorkflow = File('.github/workflows/release.yml');
  final File governanceEntry = File('tool/governance.dart');
  if (!governanceWorkflow.existsSync()) fail('governance workflow missing');
  if (!releaseWorkflow.existsSync()) fail('release workflow missing');
  if (!governanceEntry.existsSync()) fail('governance entry missing');

  final String workflow = governanceWorkflow.readAsStringSync();
  final String release = releaseWorkflow.readAsStringSync();
  final String entry = governanceEntry.readAsStringSync();

  const List<String> directCommands = <String>[
    'dart run tool/sdk_layer_graph_guard.dart',
    'dart run tool/sdk_layer_graph_guard_test.dart',
    'dart run tool/product_erasure_guard.dart',
    'dart run tool/product_erasure_guard_test.dart',
    'dart run tool/sdk_boundary_ci_binding_test.dart',
  ];
  for (final String command in directCommands) {
    expect(
        workflow.contains(command), '$command bound to PR/push governance CI');
  }
  expect(
    entry.contains("import 'sdk_layer_graph_guard.dart' as layer_graph;"),
    'governance entry imports Layer Graph Guard',
  );
  expect(
    entry.contains("import 'product_erasure_guard.dart' as product_erasure;"),
    'governance entry imports Product-Erasure Guard',
  );
  expect(
    entry.contains('layer_graph.checkSdkLayerGraph(root)'),
    'governance entry invokes Layer Graph Guard',
  );
  expect(
    entry.contains('product_erasure.checkProductErasure(root)'),
    'governance entry invokes Product-Erasure Guard',
  );
  expect(
    release.contains('dart run tool/governance.dart'),
    'release CI inherits boundary guards through governance.dart',
  );
  expect(
    !workflow.contains('sdk_layer_graph_guard.dart --update') &&
        !workflow.contains('product_erasure_guard.dart --update'),
    'boundary CI has no self-approval/update mode',
  );
  stdout.writeln('SDK boundary CI binding regression: PASS');
}
