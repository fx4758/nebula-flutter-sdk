/// Secret value scanner (F0-05).
///
/// Detects hard-coded credential *values* across the working tree — private
/// key blocks, cloud access keys, provider API keys and long secret-ish
/// assignments. This complements the identifier-level source patterns already
/// enforced by the governance guard (`SEC-*` rules in policy.json).
///
/// ```bash
/// dart run tool/secret_scan.dart            # validate (non-zero exit on hit)
/// ```
///
/// Deliberately high-precision: patterns require strong signal (key block
/// markers, well-known prefixes, or secret keyword + long value) to avoid
/// flagging fixture/test strings. Configurable ignore paths keep policy
/// definitions and intentional fixtures out of scope.
library;

import 'dart:io';

/// Snapshot/config files that intentionally contain secret-like examples or
/// structured samples; never scanned.
const List<String> _defaultIgnorePaths = <String>[
  '.git',
  '.dart_tool',
  'build',
  'governance/policy.json',
  'test/fixtures',
];

final List<RegExp> _patterns = <RegExp>[
  // Private key blocks (RSA/EC/OpenSSH/DSA/Ed25519).
  RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----'),
  // AWS access key id.
  RegExp(r'\bAKIA[0-9A-Z]{16}\b'),
  // OpenAI-style provider keys.
  RegExp(r'\bsk-[A-Za-z0-9]{20,}\b'),
  // Generic secret-ish assignment with a long quoted value (>= 20 chars).
  RegExp(
    r'(?:api[_-]?key|apikey|secret|passwd|password|refresh_token|access_token|private[_-]?key)'
            r'\s*[=:]\s*["' +
        "'" +
        r'][A-Za-z0-9_\-+/=]{20,}["' +
        "'" +
        r']',
    caseSensitive: false,
  ),
];

/// A secret-scan finding.
final class SecretHit {
  const SecretHit(this.ruleId, this.path, this.reason);

  final String ruleId;
  final String path;
  final String reason;

  @override
  String toString() => '[$ruleId] $path: $reason';
}

/// Scans [root] for hard-coded credential values. Reused by the governance
/// guard and runnable standalone.
List<SecretHit> scanForSecrets(Directory root, {List<String>? ignorePaths}) {
  final Set<String> ignored = (ignorePaths ?? _defaultIgnorePaths)
      .map((String p) => _normalize(p))
      .toSet();
  final List<SecretHit> hits = <SecretHit>[];
  _walk(root, root, ignored, hits);
  return hits;
}

void _walk(
  Directory root,
  Directory dir,
  Set<String> ignored,
  List<SecretHit> hits,
) {
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    final String relative = entity.path.substring(root.path.length + 1);
    final String normalized = _normalize(relative);
    if (ignored.contains(normalized) ||
        ignored.any((String prefix) => normalized.startsWith('$prefix/'))) {
      continue;
    }
    if (entity is Directory) {
      _walk(root, entity, ignored, hits);
    } else if (entity is File) {
      _scanFile(relative, entity, hits);
    }
  }
}

void _scanFile(String relative, File file, List<SecretHit> hits) {
  // Only scan text-ish files; skip binaries and the lockfile hash noise.
  final String lower = relative.toLowerCase();
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.ico') ||
      lower.endsWith('.pubspec.lock')) {
    return;
  }
  final String content;
  try {
    content = file.readAsStringSync();
  } on Object {
    return; // binary or unreadable
  }
  for (final RegExp pattern in _patterns) {
    final RegExpMatch? match = pattern.firstMatch(content);
    if (match != null) {
      hits.add(SecretHit('SEC-SCAN', relative, pattern.pattern));
      return; // one hit per file is enough to gate
    }
  }
}

String _normalize(String path) => path.replaceAll(r'\', '/');

void main(List<String> args) {
  final Directory root = Directory.current;
  final bool ignoreFix = args.contains('--ignore-fix');
  final List<SecretHit> hits = scanForSecrets(root);
  if (hits.isEmpty) {
    stdout.writeln('Secret scan: PASS (no hard-coded credential values)');
    return;
  }
  stderr.writeln(
      'Secret scan: FAIL (${hits.length} file(s) with credential-like values)');
  for (final SecretHit hit in hits) {
    stderr.writeln(hit);
  }
  stderr.writeln(
      'Move secrets to configuration/Ports; add an ignore path only via '
      'governance/policy.json after explicit review'
      '${ignoreFix ? ' (--ignore-fix acknowledged)' : ''}.');
  exitCode = 1;
}
