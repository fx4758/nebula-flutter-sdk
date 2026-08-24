/// Login request contract (F1-02 / Auth V2).
library;

import 'dart:convert';

/// Supported login providers.
enum NebulaLoginProvider { phone, email, oauth }

/// Supported OAuth providers for Auth V2.
enum NebulaOAuthProvider { apple, google }

/// Purpose bound to an EMAIL verification code.
enum NebulaEmailCodePurpose { register, resetPassword }

/// Immutable login request.
final class NebulaLoginRequest {
  const NebulaLoginRequest.phone({required this.phone, required this.code})
      : provider = NebulaLoginProvider.phone,
        email = null,
        password = null,
        oauthProvider = null,
        oauthCode = null;

  const NebulaLoginRequest.email({required this.email, required this.password})
      : provider = NebulaLoginProvider.email,
        phone = null,
        code = null,
        oauthProvider = null,
        oauthCode = null;

  const NebulaLoginRequest.oauth({
    required this.oauthProvider,
    required this.oauthCode,
  })  : provider = NebulaLoginProvider.oauth,
        phone = null,
        code = null,
        email = null,
        password = null;

  final NebulaLoginProvider provider;
  final String? phone;
  final String? code;
  final String? email;
  final String? password;
  final NebulaOAuthProvider? oauthProvider;
  final String? oauthCode;

  /// Validates request bounds before any network call.
  void validate() {
    switch (provider) {
      case NebulaLoginProvider.phone:
        _requireLegacy(phone, 'phone');
        _requireLegacy(code, 'code');
      case NebulaLoginProvider.email:
        _requireUtf8(email, 'email', minBytes: 1, maxBytes: 254);
        _requireUtf8(password, 'password', minBytes: 8, maxBytes: 128);
      case NebulaLoginProvider.oauth:
        _requireUtf8(oauthCode, 'oauthCode', minBytes: 1, maxBytes: 4096);
    }
  }

  /// Wire body for the `/api/v1/mobile/auth/login` endpoint.
  Map<String, Object?> toJson() => switch (provider) {
        NebulaLoginProvider.phone => <String, Object?>{
            'provider': 'PHONE',
            'phone': phone,
            'code': code,
          },
        NebulaLoginProvider.email => <String, Object?>{
            'provider': 'EMAIL',
            'email': email,
            'password': password,
          },
        NebulaLoginProvider.oauth => <String, Object?>{
            'provider': 'OAUTH',
            'oauth_provider': switch (oauthProvider!) {
              NebulaOAuthProvider.apple => 'APPLE',
              NebulaOAuthProvider.google => 'GOOGLE',
            },
            'oauth_code': oauthCode,
          },
      };

  // PHONE keeps its pre-V2 compatibility bounds and behavior.
  void _requireLegacy(String? value, String field) {
    if (value == null || value.isEmpty || value.length > 128) {
      throw ArgumentError.value(
        value,
        field,
        'must be non-empty and <= 128 chars',
      );
    }
  }

  // Auth V2 secrets are deliberately omitted from exception messages.
  void _requireUtf8(
    String? value,
    String field, {
    required int minBytes,
    required int maxBytes,
  }) {
    if (value == null) throw ArgumentError('$field is required', field);
    final int bytes = utf8.encode(value).length;
    if (bytes < minBytes || bytes > maxBytes) {
      throw ArgumentError(
        '$field must be $minBytes..$maxBytes UTF-8 bytes',
        field,
      );
    }
  }
}
