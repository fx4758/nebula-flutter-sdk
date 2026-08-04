/// Storage namespace helpers (F1-03).
///
/// Canonical local key namespace per docs/02 §2:
///   `environment/app_id/user_id/key`
/// - App scope (no user):   `environment/appId`
/// - User scope:             `environment/appId/userId`
///
/// [StorageNamespace] builds the *prefix*; the trailing relative `key` is
/// appended via [key]. Storage Ports take `(namespace, key)` separately
/// (identical shape to [SecureTokenStore]), so the physical key is
/// `namespace/key`.
library;

import '../foundation/options.dart';

/// Canonical storage namespace (docs/02 §2).
///
/// Immutable builder for the `environment/app_id[/user_id]` prefix. The
/// trailing storage `key` is appended with [key].
///
/// Segment sanitization ([_seg]) forbids empty values and `/`/NUL inside any
/// segment, because a `/` would collapse namespace boundaries and leak data
/// across App/user/environment scopes.
final class StorageNamespace {
  StorageNamespace._(this._prefix);

  /// App-scoped namespace (no user segment): `environment/appId`.
  factory StorageNamespace.app(
    NebulaEnvironment environment,
    String appId,
  ) =>
      StorageNamespace._(_join(environment.name, _seg(appId, 'appId')));

  /// User-scoped namespace (adds the user segment): `environment/appId/userId`.
  factory StorageNamespace.user(
    NebulaEnvironment environment,
    String appId,
    String userId,
  ) =>
      StorageNamespace._(
        _join(environment.name, _seg(appId, 'appId'), _seg(userId, 'userId')),
      );

  final String _prefix;

  /// Appends a relative key to this namespace.
  ///
  /// Example: `StorageNamespace.user(prod, 'app', 'u1').key('refresh_token')`
  /// → `production/app/u1/refresh_token`.
  String key(String relativeKey) => _join(_prefix, _seg(relativeKey, 'key'));

  /// Namespace prefix without the trailing key (e.g. `production/app/u1`).
  @override
  String toString() => _prefix;

  static String _join(String head, String tail, [String? extra]) =>
      extra == null ? '$head/$tail' : '$head/$tail/$extra';

  /// Rejects empty or scope-breaking segments.
  static String _seg(String value, String role) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, role, 'must not be empty');
    }
    if (value.contains('/') || value.contains('\x00')) {
      throw ArgumentError.value(
        value,
        role,
        'must not contain "/" or NUL (would break storage namespace scoping)',
      );
    }
    return value;
  }
}
