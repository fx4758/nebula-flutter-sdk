import 'dart:convert';
import 'dart:io';

Never fail(String message) {
  stderr.writeln('COORDINATOR-PUBLICATION-MODE: FAIL — $message');
  exit(1);
}

void main(List<String> args) {
  final ei = args.indexOf('--event-path');
  if (ei < 0 || ei + 1 >= args.length) {
    fail('usage: --event-path <forgejo-event-json>');
  }
  final file = File(args[ei + 1]);
  if (!file.existsSync()) fail('event file missing: ${file.path}');
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>) fail('event payload is not an object');
  final pr = value['pull_request'];
  if (pr is! Map<String, dynamic>) fail('pull_request missing');
  final base = pr['base'];
  if (base is! Map<String, dynamic>) fail('pull_request.base missing');
  final baseRef = base['ref']?.toString() ?? '';
  if (baseRef != 'main') {
    stdout.writeln('implementation');
    return;
  }
  final labels = pr['labels'];
  if (labels is! List) {
    stdout.writeln('implementation');
    return;
  }
  final names = labels
      .whereType<Map<String, dynamic>>()
      .map((e) => e['name']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet();
  stdout.writeln(
    names.contains('coordinator-publication')
        ? 'coordinator'
        : 'implementation',
  );
}
