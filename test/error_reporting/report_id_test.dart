import 'package:nebula_sdk/src/error_reporting/report_id.dart';
import 'package:test/test.dart';

void main() {
  test('secure report IDs are UUIDv4-shaped and unique across sample', () {
    final SecureErrorReportIdGenerator generator =
        SecureErrorReportIdGenerator();
    final RegExp uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final Set<String> ids = <String>{};
    for (int i = 0; i < 256; i++) {
      final String id = generator.nextId();
      expect(id, matches(uuidV4));
      ids.add(id);
    }
    expect(ids, hasLength(256));
  });
}
