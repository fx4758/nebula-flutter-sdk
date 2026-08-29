import 'dart:io';

Never fail(String message) {
  stderr.writeln('GOVERNANCE-PR-CHECKOUT-CONTRACT: FAIL — $message');
  exit(1);
}

void requireContains(String text, String needle) {
  if (!text.contains(needle)) {
    fail('missing contract fragment: $needle');
  }
}

void main() {
  final file = File('.github/workflows/governance.yml');
  if (!file.existsSync()) {
    fail('governance workflow missing');
  }
  final workflow = file.readAsStringSync();

  requireContains(workflow, 'PR_NUMBER=');
  requireContains(workflow, 'HEAD_SHA=');
  requireContains(workflow, r'refs/pull/${PR_NUMBER}/head');
  requireContains(workflow, 'FETCHED_SHA=');
  requireContains(workflow, r'test "$FETCHED_SHA" = "$HEAD_SHA"');
  requireContains(
    workflow,
    "fetch --no-tags origin '+refs/heads/*:refs/remotes/origin/*'",
  );
  requireContains(workflow, r'refs/remotes/origin/$HEAD_REF');

  if (workflow.contains("print(pr['head']['ref'])")) {
    fail('pull-request checkout must not treat AGit head.ref as a branch');
  }

  stdout.writeln('GOVERNANCE-PR-CHECKOUT-CONTRACT: PASS');
}
