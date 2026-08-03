import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  ProofCanonicalInput input() => const ProofCanonicalInput(
        method: 'POST',
        path: '/api/v1/mobile/auth/login',
        timestamp: '1725300000',
        nonce: 'nonce-1',
        bodySha256: 'abc123',
        tokenSha256: 'def456',
      );

  group('ProofCanonicalInput.canonicalize (docs/08 §5 frozen)', () {
    test('is deterministic: same input, same bytes', () {
      expect(input().canonicalize(), input().canonicalize());
    });

    test('joins the seven frozen segments with \\n in frozen order', () {
      expect(
        input().canonicalize(),
        'V1\nPOST\n/api/v1/mobile/auth/login\n1725300000\nnonce-1\nabc123\ndef456',
      );
    });

    test(
        'order is VERSION/METHOD/PATH/TIMESTAMP/NONCE/BODY_SHA256/TOKEN_SHA256',
        () {
      final segments = input().canonicalize().split('\n');
      expect(segments, hasLength(7));
      expect(segments[0], nebulaProofVersion); // VERSION
      expect(segments[1], 'POST'); // METHOD
      expect(segments[2], '/api/v1/mobile/auth/login'); // PATH
      expect(segments[3], '1725300000'); // TIMESTAMP
      expect(segments[4], 'nonce-1'); // NONCE
      expect(segments[5], 'abc123'); // BODY_SHA256
      expect(segments[6], 'def456'); // INSTALLATION_TOKEN_SHA256
    });

    test('any mutated field produces different canonical bytes', () {
      final base = input().canonicalize();
      expect(
        const ProofCanonicalInput(
          method: 'PUT',
          path: '/api/v1/mobile/auth/login',
          timestamp: '1725300000',
          nonce: 'nonce-1',
          bodySha256: 'abc123',
          tokenSha256: 'def456',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/logout',
          timestamp: '1725300000',
          nonce: 'nonce-1',
          bodySha256: 'abc123',
          tokenSha256: 'def456',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/login',
          timestamp: '9999999999',
          nonce: 'nonce-1',
          bodySha256: 'abc123',
          tokenSha256: 'def456',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/login',
          timestamp: '1725300000',
          nonce: 'nonce-2',
          bodySha256: 'abc123',
          tokenSha256: 'def456',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/login',
          timestamp: '1725300000',
          nonce: 'nonce-1',
          bodySha256: 'abc124',
          tokenSha256: 'def456',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/login',
          timestamp: '1725300000',
          nonce: 'nonce-1',
          bodySha256: 'abc123',
          tokenSha256: 'def457',
        ).canonicalize(),
        isNot(base),
      );
      expect(
        const ProofCanonicalInput(
          method: 'POST',
          path: '/api/v1/mobile/auth/login',
          timestamp: '1725300000',
          nonce: 'nonce-1',
          bodySha256: 'abc123',
          tokenSha256: 'def456',
          version: 'V2',
        ).canonicalize(),
        isNot(base),
      );
    });

    test('newline framing is unambiguous (no trailing newline)', () {
      expect(input().canonicalize().endsWith('\n'), isFalse);
    });
  });

  group('RecordingProofSigner (proof Port contract)', () {
    test('feeds the exact frozen canonical bytes to the signer', () async {
      final signer = RecordingProofSigner();
      final canonical = await signer.signProof(input());
      expect(signer.signed, hasLength(1));
      expect(signer.signed.single, input().canonicalize());
      expect(canonical, isNotEmpty);
      expect(canonical, isNot(input().canonicalize())); // signature, not input
    });
  });
}
