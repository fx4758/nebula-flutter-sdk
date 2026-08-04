/// Request-proof header builder (F1-02 surface, F2-01 relocated).
///
/// The implementation now lives in `transport/proof_headers.dart` (its
/// protocol-level home, shared by every mobile capability). This file is kept
/// as a re-export so existing imports (`package:nebula_sdk` and internal
/// `auth/` consumers) keep resolving `buildAuthHeaders` unchanged.
library;

export '../transport/proof_headers.dart' show buildAuthHeaders;
