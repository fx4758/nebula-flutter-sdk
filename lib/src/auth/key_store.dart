/// Installation key Port (FS-01).
///
/// Abstract key generation and signing for installation trust (docs/08 §4/§6.2).
/// The SDK core deliberately contains no concrete plugin here: platform
/// secure-key-store implementations (non-exportable keys, attestation-backed
/// storage) are supplied by the host app. Nothing in this file depends on a
/// Provider SDK or on crypto plugin packages.
library;

/// The public side of an installation key pair.
///
/// `privateKeyRef` is an opaque handle into the platform secure key store
/// (e.g. Keychain/Keystore entry name) — never the private key material.
final class InstallationKeyPair {
  const InstallationKeyPair({
    required this.publicKeyDer,
    required this.publicKeyThumbprint,
    required this.privateKeyRef,
  });

  /// ES256/P-256 public key, DER SPKI, base64url encoded (docs/08 §4.1
  /// `public_key`; exact encoding is pinned by F0-04 fixtures).
  final String publicKeyDer;

  /// SHA-256 over the public key bytes, server-comparable fingerprint
  /// (FB-02 stores only the thumbprint server-side).
  final String publicKeyThumbprint;

  /// Platform secure-store reference for signing; never a raw private key.
  final String privateKeyRef;
}

/// Key-generation/signing Port for installation trust (FS-01).
///
/// Contract:
/// - [generateKeyPair] creates a fresh installation key pair. Reinstall or
///   secure-key loss MUST create a new identity; the old private key is never
///   recovered (docs/08 §4.3).
/// - [sign] produces a detached ES256/P-256 signature over [message] (the
///   canonical proof string, see `lib/src/auth/proof.dart`), using the key
///   referenced by [keyRef].
abstract interface class InstallationKeyPort {
  Future<InstallationKeyPair> generateKeyPair();

  /// Returns base64url-encoded ES256/P-256 signature bytes.
  Future<String> sign({
    required String keyRef,
    required String message,
  });
}

/// In-memory fake used by tests and as a reference behavior sketch.
///
/// Not a production implementation: it records signing inputs so callers can
/// assert deterministic canonicalization without a real platform key store.
final class FakeInstallationKeyPort implements InstallationKeyPort {
  FakeInstallationKeyPort();

  final List<String> signedMessages = <String>[];
  int _serial = 0;

  @override
  Future<InstallationKeyPair> generateKeyPair() async {
    _serial += 1;
    final thumbprint = 'fp-fake-$_serial';
    return InstallationKeyPair(
      publicKeyDer: 'public-key-fake-$_serial',
      publicKeyThumbprint: thumbprint,
      privateKeyRef: 'ref-fake-$_serial',
    );
  }

  @override
  Future<String> sign({
    required String keyRef,
    required String message,
  }) async {
    signedMessages.add(message);
    // Deterministic fake signature: SHA-256-style hex of keyRef+message.
    return 'sig-$keyRef-${message.hashCode}';
  }
}
