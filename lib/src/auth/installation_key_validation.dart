library;

import 'dart:convert';
import 'dart:typed_data';

const List<int> _p256SpkiPrefix = <int>[
  0x30,
  0x59,
  0x30,
  0x13,
  0x06,
  0x07,
  0x2a,
  0x86,
  0x48,
  0xce,
  0x3d,
  0x02,
  0x01,
  0x06,
  0x08,
  0x2a,
  0x86,
  0x48,
  0xce,
  0x3d,
  0x03,
  0x01,
  0x07,
  0x03,
  0x42,
  0x00,
  0x04,
];

final BigInt _p256Prime = BigInt.parse(
  'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF',
  radix: 16,
);
final BigInt _p256B = BigInt.parse(
  '5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B',
  radix: 16,
);

/// Client-side fail-fast validation for Backend-authoritative P-256 SPKI.
/// Server validation remains authoritative; no private-key capability lives here.
void validateP256SpkiBase64Url(String value, {required int maxUtf8Bytes}) {
  final int wireBytes = utf8.encode(value).length;
  if (value.isEmpty || wireBytes > maxUtf8Bytes) {
    throw ArgumentError.value(
      wireBytes,
      'publicKey',
      'must be non-empty and <= $maxUtf8Bytes UTF-8 bytes',
    );
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+={0,2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'publicKey', 'must be base64url');
  }

  final Uint8List der;
  try {
    der = base64Url.decode(base64Url.normalize(value));
  } on FormatException {
    throw ArgumentError.value(value, 'publicKey', 'must be valid base64url');
  }

  if (der.length != _p256SpkiPrefix.length + 64) {
    throw ArgumentError.value(
      der.length,
      'publicKey',
      'must be a P-256 SPKI DER public key',
    );
  }
  for (int i = 0; i < _p256SpkiPrefix.length; i++) {
    if (der[i] != _p256SpkiPrefix[i]) {
      throw ArgumentError.value(
        value,
        'publicKey',
        'must use id-ecPublicKey + prime256v1 SPKI DER',
      );
    }
  }

  final int offset = _p256SpkiPrefix.length;
  final BigInt x = _bigEndian(der.sublist(offset, offset + 32));
  final BigInt y = _bigEndian(der.sublist(offset + 32, offset + 64));
  if (x >= _p256Prime || y >= _p256Prime) {
    throw ArgumentError.value(value, 'publicKey', 'P-256 point out of range');
  }
  final BigInt lhs = (y * y) % _p256Prime;
  final BigInt rhs =
      ((x * x % _p256Prime) * x - BigInt.from(3) * x + _p256B) % _p256Prime;
  if (lhs != rhs) {
    throw ArgumentError.value(value, 'publicKey', 'invalid P-256 curve point');
  }
}

BigInt _bigEndian(List<int> bytes) {
  BigInt value = BigInt.zero;
  for (final int byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}
