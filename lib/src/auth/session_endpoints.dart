/// Endpoint paths for the mobile user-session routes (docs/08 §4.3).
///
/// Defaults follow ADR-F008: mobile auth lives under `/api/v1/mobile/auth/*`.
/// The legacy `/api/v1/auth/*` prefix is reserved for the compatibility routes
/// and must never be used for the new client (docs/08 §10, MB-05).
///
/// The transport resolves `baseUri + path`, so [baseUri] should be the API
/// origin root (e.g. `https://api.example.com`) and these paths carry the full
/// `/api/v1/mobile/...` prefix.
final class SessionEndpoints {
  const SessionEndpoints({
    this.login = '/api/v1/mobile/auth/login',
    this.refresh = '/api/v1/mobile/auth/refresh',
    this.logout = '/api/v1/mobile/auth/logout',
  });

  final String login;
  final String refresh;
  final String logout;
}
