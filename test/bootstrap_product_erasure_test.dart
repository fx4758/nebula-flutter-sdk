import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('bootstrap production surface is product-name independent', () {
    const paths = <String>[
      'lib/src/auth/bootstrap_client.dart',
      'lib/src/auth/bootstrap_endpoints.dart',
      'lib/src/auth/bootstrap_errors.dart',
      'lib/src/auth/installation.dart',
      'lib/src/auth/installation_key_validation.dart',
    ];
    final String source =
        paths.map((p) => File(p).readAsStringSync()).join('\n');
    final String normalized = source.toLowerCase();
    for (final String forbidden in <String>[
      'nfc',
      'ndef',
      'passport',
      'dynamicnote',
      'dynamic_note',
      'photocard',
      'photo_card',
      'starsprout',
      'flypost',
    ]) {
      expect(normalized, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
