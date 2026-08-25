/// Generic request-proof test double.
library;

import '../foundation/request_proof.dart';

/// Test double that records every canonical string it was asked to sign.
///
/// Used to prove that the caller's pipeline feeds the exact frozen canonical
/// bytes into the signer (deterministic canonicalization tests).
final class RecordingProofSigner implements RequestProofSigner {
  final List<String> signed = <String>[];

  @override
  Future<String> signProof(ProofCanonicalInput input) async {
    final String canonical = input.canonicalize();
    signed.add(canonical);
    return 'sig-${canonical.hashCode}';
  }
}
