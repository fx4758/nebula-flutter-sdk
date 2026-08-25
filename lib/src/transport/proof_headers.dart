/// Request-proof header builder (F2-01 relocation; protocol-level helper).
///
/// Attaches the proof headers required by the mobile target protocol
/// (docs/08 §4/§5, docs/12 §3): `X-Installation-Token`, `X-Proof-Timestamp`,
/// `X-Proof-Nonce`, `X-Device-Proof`. Lives in `transport/` (not `auth/`)
/// because it is shared by every mobile capability (auth, runtime-config, ...)
/// — capabilities must not import each other (docs/01 §3). `lib/src/auth/
/// auth_proof.dart` re-exports this so existing imports keep working.
///
/// The signature covers the frozen canonical string
/// (`VERSION\nMETHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_SHA256\nINSTALLATION_TOKEN_SHA256`)
/// produced by [ProofCanonicalInput]. Signing is delegated to the injected
/// [RequestProofSigner] Port (FS-01); the core holds no crypto plugin, and
/// raw tokens are never included in the canonical input.
library;

import 'dart:convert';
import 'dart:math';

import '../foundation/request_proof.dart';
import '../foundation/sha256.dart';
import '../transport.dart';

/// Builds the request-proof headers for one outbound mobile call.
///
/// [resolvedPath] must be the exact path the server receives (baseUri path
/// joined with the endpoint path, see [HttpTransport] resolution) so the
/// canonical proof string matches what the server recomputes.
Future<Map<String, String>> buildAuthHeaders({
  required NebulaHttpMethod method,
  required String resolvedPath,
  required Object? body,
  required String installationToken,
  required RequestProofSigner signer,
}) async {
  final String bodyJson = body == null ? '' : jsonEncode(body);
  final String bodySha256 = sha256Hex(utf8.encode(bodyJson));
  final String tokenSha256 = sha256Hex(utf8.encode(installationToken));
  final String timestamp =
      (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
  final String nonce = _secureNonce();

  final ProofCanonicalInput input = ProofCanonicalInput(
    method: method.name.toUpperCase(),
    path: resolvedPath,
    timestamp: timestamp,
    nonce: nonce,
    bodySha256: bodySha256,
    tokenSha256: tokenSha256,
  );
  final String signature = await signer.signProof(input);

  return <String, String>{
    'X-Installation-Token': installationToken,
    'X-Proof-Timestamp': timestamp,
    'X-Proof-Nonce': nonce,
    'X-Device-Proof': signature,
  };
}

/// 128-bit hex nonce derived from the OS CSPRNG.
String _secureNonce() {
  final Random random = Random.secure();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 16; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
