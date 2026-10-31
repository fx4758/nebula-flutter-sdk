import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('NebulaLoginRequest Auth V2', () {
    test('PHONE wire remains unchanged', () {
      const request = NebulaLoginRequest.phone(
        phone: '13800000000',
        code: '123456',
      );
      request.validate();
      expect(request.toJson(), <String, Object?>{
        'provider': 'PHONE',
        'phone': '13800000000',
        'code': '123456',
      });
    });

    test('EMAIL login uses EMAIL + email + password wire', () {
      const request = NebulaLoginRequest.email(
        email: 'user@example.com',
        password: 'correct-horse',
      );
      request.validate();
      expect(request.toJson(), <String, Object?>{
        'provider': 'EMAIL',
        'email': 'user@example.com',
        'password': 'correct-horse',
      });
    });

    test('OAuth provider enum maps Apple/Google exactly', () {
      const apple = NebulaLoginRequest.oauth(
        oauthProvider: NebulaOAuthProvider.apple,
        oauthCode: 'apple-code',
      );
      const google = NebulaLoginRequest.oauth(
        oauthProvider: NebulaOAuthProvider.google,
        oauthCode: 'google-code',
      );
      apple.validate();
      google.validate();
      expect(apple.toJson()['oauth_provider'], 'APPLE');
      expect(google.toJson()['oauth_provider'], 'GOOGLE');
    });

    test('Tencent mobile provider names and sensitive credential bounds', () {
      const wechat = NebulaLoginRequest.oauth(
        oauthProvider: NebulaOAuthProvider.wechat,
        oauthCode: 'wechat-one-time-code',
      );
      const qq = NebulaLoginRequest.oauth(
        oauthProvider: NebulaOAuthProvider.qq,
        oauthCode: 'qq-provider-access-credential',
      );
      wechat.validate();
      qq.validate();
      expect(wechat.toJson(), <String, Object?>{
        'provider': 'OAUTH',
        'oauth_provider': 'WECHAT',
        'oauth_code': 'wechat-one-time-code',
      });
      expect(qq.toJson(), <String, Object?>{
        'provider': 'OAUTH',
        'oauth_provider': 'QQ',
        'oauth_code': 'qq-provider-access-credential',
      });
      NebulaLoginRequest.oauth(
        oauthProvider: NebulaOAuthProvider.qq,
        oauthCode: 'a' * 4096,
      ).validate();
      expect(
        () => NebulaLoginRequest.oauth(
          oauthProvider: NebulaOAuthProvider.qq,
          oauthCode: 'b' * 4097,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('EMAIL and OAuth limits are UTF-8-byte based', () {
      final validEmail = '${'a' * 242}@example.com';
      final tooLongEmail = '${'é' * 122}@example.com';
      NebulaLoginRequest.email(
        email: validEmail,
        password: '12345678',
      ).validate();
      expect(
        () => NebulaLoginRequest.email(
          email: tooLongEmail,
          password: '12345678',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => NebulaLoginRequest.oauth(
          oauthProvider: NebulaOAuthProvider.apple,
          oauthCode: 'é' * 2049,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('secret values are not included in validation errors', () {
      const secret = 'short';
      try {
        const NebulaLoginRequest.email(
          email: 'user@example.com',
          password: secret,
        ).validate();
        fail('expected validation failure');
      } on ArgumentError catch (error) {
        expect(error.toString(), isNot(contains(secret)));
      }
    });
  });
}
