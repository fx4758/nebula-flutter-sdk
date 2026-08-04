import 'dart:convert';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:nebula_sdk/src/foundation/sha256.dart';
import 'package:test/test.dart';

void main() {
  group('buildAuthHeaders (docs/08 §4/§5)', () {
    test('attaches the four proof headers and a server-verifiable canonical',
        () async {
      final RecordingProofSigner signer = RecordingProofSigner();
      final Map<String, Object?> body = <String, Object?>{
        'provider': 'PHONE',
        'phone': '13800000000',
        'code': '123456',
      };

      final Map<String, String> headers = await buildAuthHeaders(
        method: NebulaHttpMethod.post,
        resolvedPath: '/api/v1/mobile/auth/login',
        body: body,
        installationToken: 'inst-abc',
        signer: signer,
      );

      expect(headers['X-Installation-Token'], 'inst-abc');
      // Timestamp is unix seconds (digits only).
      expect(headers['X-Proof-Timestamp'], matches(RegExp(r'^\d+$')));
      // 128-bit nonce, lowercase hex.
      expect(headers['X-Proof-Nonce'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(headers['X-Device-Proof'], isNotEmpty);

      // The signer recorded exactly one canonical string, and it matches the
      // frozen framing VERSION\nMETHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_SHA256\nTOKEN_SHA256.
      expect(signer.signed, hasLength(1));
      final List<String> parts = signer.signed.single.split('\n');
      expect(parts, hasLength(7));
      expect(parts[0], 'V1');
      expect(parts[1], 'POST');
      expect(parts[2], '/api/v1/mobile/auth/login');
      expect(parts[3], headers['X-Proof-Timestamp']);
      expect(parts[4], headers['X-Proof-Nonce']);
      expect(
        parts[5],
        sha256Hex(utf8.encode(jsonEncode(body))),
        reason: 'BODY_SHA256 must be SHA-256 of the exact JSON wire body',
      );
      expect(
        parts[6],
        sha256Hex(utf8.encode('inst-abc')),
        reason: 'INSTALLATION_TOKEN_SHA256 must be SHA-256 of the token',
      );
    });

    test('canonical excludes body SHA when there is no body', () async {
      final RecordingProofSigner signer = RecordingProofSigner();
      final Map<String, String> headers = await buildAuthHeaders(
        method: NebulaHttpMethod.post,
        resolvedPath: '/api/v1/mobile/auth/logout',
        body: null,
        installationToken: 'inst-xyz',
        signer: signer,
      );
      expect(headers['X-Device-Proof'], isNotEmpty);
      final List<String> parts = signer.signed.single.split('\n');
      // Body is empty -> SHA-256 of the empty string.
      expect(parts[5], sha256Hex(<int>[]));
    });
  });
}
