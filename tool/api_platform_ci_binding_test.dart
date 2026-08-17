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
  final File workflow = File('.github/workflows/governance.yml');
  if (!workflow.existsSync()) fail('governance workflow missing');
  final String text = workflow.readAsStringSync();

  expect(text.contains('pull_request:'), 'PR governance trigger present');
  expect(text.contains('push:'), 'main push governance trigger present');
  expect(
    text.contains('dart run tool/platform_api_guard.dart --self-check'),
    'Platform API policy self-check bound to CI',
  );
  expect(
    text.contains('dart run tool/platform_api_guard_test.dart'),
    'Platform API negative probes bound to CI',
  );
  expect(
    text.contains('dart run tool/governance_test.dart'),
    'governance negative probes bound to CI',
  );
  expect(
    text.contains('dart run tool/api_surface.dart'),
    'public API surface snapshot bound to CI',
  );
  expect(
    !text.contains('dart run tool/api_surface.dart --update'),
    'CI cannot self-approve API surface drift',
  );
  stdout.writeln('API + Platform CI binding regression: PASS');
}
