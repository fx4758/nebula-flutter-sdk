/// Request proof Port and canonicalization (FS-01).
///
/// Freezes the canonical proof input from
/// docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md §5:
///
/// ```text
/// VERSION\nMETHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_SHA256\nINSTALLATION_TOKEN_SHA256
/// ```
///
/// The canonicalization itself is a pure, deterministic function (tested
/// exhaustively). Signing is delegated to a Port; the core contains no
/// concrete crypto plugin.
library;

/// The frozen canonical proof version (docs/08 §5: ES256/P-256 for V1).
const String nebulaProofVersion = 'V1';

/// Canonical input to an ES256/P-256 request proof (docs/08 §5).
///
/// `bodySha256` and `tokenSha256` are hex digests of the request body and the
/// installation token respectively. Computing those digests is a transport
/// concern (no crypto dependency in core); this class only pins the ordering
/// and framing that the signature is computed over.
final class ProofCanonicalInput {
  const ProofCanonicalInput({
    required this.method,
    required this.path,
    required this.timestamp,
    required this.nonce,
    required this.bodySha256,
    required this.tokenSha256,
    this.version = nebulaProofVersion,
  });

  /// HTTP method verb, upper case (e.g. `POST`).
  final String method;

  /// Full request path including any API prefix (e.g. `/api/v1/mobile/auth/login`).
  /// Mobile auth endpoints live under `/api/v1/mobile/auth/*` (ADR-F008); the
  /// legacy `/api/v1/auth/*` prefix is reserved and must never be used here.
  /// URL query is excluded by contract — ambiguous query strings must be
  /// canonicalized separately by the endpoint or rejected (docs/08 §5).
  final String path;

  /// Unix seconds as decimal string. Server tolerance ≤ 5 minutes.
  final String timestamp;

  /// Client-generated replay nonce (scoped by app+installation server-side).
  final String nonce;
  final String bodySha256;
  final String tokenSha256;
  final String version;

  /// Deterministic canonical string: the exact bytes a proof signature covers.
  ///
  /// Order and framing are frozen by docs/08 §5 — do not reorder or change the
  /// separator without a fixture freeze and ADR.
  String canonicalize() => [
        version,
        method,
        path,
        timestamp,
        nonce,
        bodySha256,
        tokenSha256
      ].join('\n');
}

/// Request proof signing Port (FS-01).
///
/// Signs the canonical string produced by [ProofCanonicalInput.canonicalize]
/// with the installation private key. Implementations return base64url-encoded
/// ES256/P-256 signature bytes (`X-Device-Proof` header value).
abstract interface class RequestProofSigner {
  Future<String> signProof(ProofCanonicalInput input);
}
