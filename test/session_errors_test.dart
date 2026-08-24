import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('classifySessionError (docs/08 §8 categories)', () {
    test('maps every frozen backend code to its category', () {
      expect(
        classifySessionError(statusCode: 200, code: 12001),
        isA<InvalidInstallationError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 12002),
        isA<SessionRevokedError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 12003),
        isA<ClientOutdatedError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 12004),
        isA<TemporarilyUnavailableError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 10001),
        isA<InvalidCredentialsError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 10003),
        isA<AuthenticationRequiredError>(),
      );
      expect(
        classifySessionError(statusCode: 200, code: 30001),
        isA<InvalidRequestError>(),
      );
    });

    test('HTTP 429 or code 40002 is rate limited with Retry-After', () {
      final e = classifySessionError(
        statusCode: 429,
        code: 40002,
        retryAfterSeconds: 30,
      );
      expect(e, isA<RateLimitedError>());
      expect((e as RateLimitedError).retryAfterSeconds, 30);
    });

    test('unknown codes fall back to authentication required, preserving code',
        () {
      final e =
          classifySessionError(statusCode: 200, code: 99999, requestId: 'r-1');
      expect(e, isA<AuthenticationRequiredError>());
      expect(e.code, 99999);
      expect(e.requestId, 'r-1');
    });
  });
}
