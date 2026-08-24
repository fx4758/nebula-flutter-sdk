# Nebula Flutter SDK Integration Guide — 0.1.0-rc2

RC2 is distributed as an immutable Forgejo Git tag. It is not a registry release and does not override each consumer repository's dependency governance.

## 1. Consume an immutable identity

Where direct Git dependencies are allowed:

```yaml
nebula_sdk:
  git:
    url: http://192.168.31.102:3000/root/nebula-flutter-sdk.git
    ref: v0.1.0-rc2
```

Never use `main`, `dev` or another floating branch. Commit the consumer lockfile. Products using vendored/snapshot pins must resolve the tag to its exact commit and repin atomically through their existing review process.

## 2. Keep one App-owned adapter/composition root

Product UI/business code should depend on App-owned interfaces. Only the platform/integration adapter should import Nebula SDK directly. Do not hand-author Nebula endpoint paths or Auth JSON in feature code.

## 3. Installation / proof boundary

The host continues to provide stable installation identity, native/non-exportable P-256 key lifecycle, a `RequestProofSigner`, secure installation-token persistence/renewal, and host lifecycle/fail-soft startup policy.

Do not embed App Secret, signing private keys, admin credentials, OAuth client secrets or provider private material in Dart configuration.

## 4. PHONE login remains compatible

```dart
await auth.login(
  NebulaLoginRequest.phone(phone: phone, code: smsCode),
);
```

RC2 does not remove or downgrade PHONE/SMS behavior.

## 5. EMAIL/password flows

Login:

```dart
await auth.login(
  NebulaLoginRequest.email(email: email, password: password),
);
```

Registration:

```dart
await auth.sendEmailCode(
  email: email,
  purpose: NebulaEmailCodePurpose.register,
);

await auth.registerEmail(
  email: email,
  password: password,
  code: verificationCode,
);
```

Password reset:

```dart
await auth.sendEmailCode(
  email: email,
  purpose: NebulaEmailCodePurpose.resetPassword,
);

await auth.resetEmailPassword(
  email: email,
  code: verificationCode,
  newPassword: newPassword,
);
```

Successful password reset clears the current local user session while preserving installation identity.

## 6. Apple / Google login

The App/provider adapter obtains a short-lived authorization code using the platform/provider SDK. Nebula receives only that code and a typed provider:

```dart
await auth.login(
  NebulaLoginRequest.oauth(
    oauthProvider: NebulaOAuthProvider.apple,
    oauthCode: appleAuthorizationCode,
  ),
);
```

Use `.google` for Google. Do not pass arbitrary provider strings. Provider credentials/configuration and authorization-code acquisition are separate App/provider integration responsibilities.

## 7. Invalid credentials

Consumer adapters may map `InvalidCredentialsError` to product copy without exposing Backend/provider internals. Do not log passwords, verification codes or OAuth authorization codes.

## 8. Existing Config / Observability integration

RC1 Runtime Config, Analytics, Error Reporting and `NebulaMobileObservability.create(...)` integration remain unchanged. Telemetry must remain fail-soft and privacy-bounded.

## 9. Consumer verification

SDK release acceptance is not App acceptance. Each consumer must run its own immutable repin review, adapter tests, platform-provider tests, privacy/secret checks and release gates.

## 10. Rollback

Tags are immutable. A consumer can roll back from RC2 to its previously accepted immutable SDK identity. Fixes publish a later tag; never retarget `v0.1.0-rc2`.
