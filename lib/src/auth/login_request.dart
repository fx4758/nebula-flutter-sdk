/// Login request contract (F1-02).
///
/// Mirrors the docs/08 §4.3 mobile auth routes: phone/code, or a supported
/// provider OAuth exchange. Field names and limits follow docs/08 §4.1 (string
/// maximum 128 characters). The request is validated locally before any network
/// call (docs/06 §2: input objects are immutable and validated up front).
library;

/// Supported login providers (docs/08 §4.3).
///
/// OAuth remains disabled until a real adapter exists (MB-12); the SDK only
/// models the input shape so the contract is stable.
enum NebulaLoginProvider { phone, oauth }

/// Immutable login request (F1-02).
final class NebulaLoginRequest {
  const NebulaLoginRequest.phone({
    required this.phone,
    required this.code,
  })  : provider = NebulaLoginProvider.phone,
        oauthProvider = null,
        oauthCode = null;

  const NebulaLoginRequest.oauth({
    required this.oauthProvider,
    required this.oauthCode,
  })  : provider = NebulaLoginProvider.oauth,
        phone = null,
        code = null;

  final NebulaLoginProvider provider;
  final String? phone;
  final String? code;
  final String? oauthProvider;
  final String? oauthCode;

  /// Applies the docs/08 §4.1 string caps (non-empty, <= 128 chars).
  void validate() {
    switch (provider) {
      case NebulaLoginProvider.phone:
        _require(phone, 'phone');
        _require(code, 'code');
      case NebulaLoginProvider.oauth:
        _require(oauthProvider, 'oauthProvider');
        _require(oauthCode, 'oauthCode');
    }
  }

  /// Wire body for the `/api/v1/mobile/auth/login` endpoint.
  Map<String, Object?> toJson() => switch (provider) {
        NebulaLoginProvider.phone => <String, Object?>{
            'provider': 'PHONE',
            'phone': phone,
            'code': code,
          },
        NebulaLoginProvider.oauth => <String, Object?>{
            'provider': 'OAUTH',
            'oauth_provider': oauthProvider,
            'oauth_code': oauthCode,
          },
      };

  void _require(String? value, String field) {
    if (value == null || value.isEmpty || value.length > 128) {
      throw ArgumentError.value(
        value,
        field,
        'must be non-empty and <= 128 chars',
      );
    }
  }
}
