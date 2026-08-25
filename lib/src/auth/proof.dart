/// Backward-compatible request-proof exports.
///
/// Runtime ownership moved to `foundation/request_proof.dart`; the recording
/// test double moved to `testing/recording_proof_signer.dart`. Existing imports
/// of `src/auth/proof.dart` remain source-compatible during this migration.
library;

export '../foundation/request_proof.dart';
export '../testing/recording_proof_signer.dart';
