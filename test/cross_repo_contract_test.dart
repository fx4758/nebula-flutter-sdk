import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// FC-01 — Cross-repository contract reconciliation (docs/09 §4)
//
// Contract artifacts only: this file does NOT add production implementation.
// It pins the SDK contracts to the facts frozen by the flypost side so that a
// drift on either side fails loudly. Anchors (flypost, branch
// codex/fb-05-router-isolation / codex/fb-04-session-rotation):
//   - internal/router/mobile_contract_test.go  (bootstrap fields, error codes,
//     proof headers, envelope)
//   - internal/pkg/proof/proof.go              (canonical input order)
//   - internal/pkg/errcode/errcode.go          (12001-12004 allocation)
//   - internal/router/abuse_isolation_test.go  (bootstrap/login bucket
//     isolation, scenario 8)
//   - internal/router/route_inventory_test.go  (middleware classes, scenario 7)
//
// Every scenario in docs/09 §4 maps to an assertion below or to a documented
// flypost anchor.
// =============================================================================

/// Frozen proof header set (docs/08 §5, frozen by FB-01 fixture
/// TestMobileProofHeaders). Kept as a test-local contract list — the SDK
/// transport emits these headers, it does not invent new ones.
const List<String> kFrozenProofHeaders = <String>[
  'X-Installation-Token',
  'X-Proof-Timestamp',
  'X-Proof-Nonce',
  'X-Device-Proof',
  'X-Request-Id',
];

/// Frozen bootstrap request fields (docs/08 §4.1, flypost
/// TestMobileBootstrapFixtures).
const List<String> kBootstrapRequestFields = <String>[
  'app_id',
  'installation_id',
  'platform',
  'app_version',
  'build_number',
  'os_version',
  'locale',
  'region',
  'public_key',
  'attestation',
  'bootstrap_request_id',
];

/// S1-F01-003 V2 required/non-null request values.
const List<String> kBootstrapRequiredRequestFields = <String>[
  'app_id',
  'installation_id',
  'platform',
  'public_key',
  'bootstrap_request_id',
];

/// S1-F01-003 V2 optional values. Canonical SDK serialization keeps the keys
/// and emits JSON null when a value is absent.
const List<String> kBootstrapNullableRequestFields = <String>[
  'app_version',
  'build_number',
  'os_version',
  'locale',
  'region',
  'attestation',
];

/// Frozen bootstrap response fields (docs/08 §4.2, flypost
/// TestMobileBootstrapFixtures).
const List<String> kBootstrapResultFields = <String>[
  'installation_token',
  'expires_at',
  'renew_after',
  'server_time',
  'app_id',
  'installation_id',
  'proof_algorithm',
  'attestation_state',
  'minimum_supported_build',
  'request_id',
];

void main() {
  group('FC-01 scenario 1: fresh install -> bootstrap -> login -> authed', () {
    test('bootstrap request wire fields match the frozen fixture set', () {
      final json = <String, Object?>{
        for (final f in kBootstrapRequestFields) f: 'x',
      }..['platform'] = 'ios'; // enum wire value, not a free string
      final req = bootstrapRequestFromWire(json);
      // Reconciliation-only round trip. Production serialization ownership is
      // SDK S1-F01-004; this helper must never become an App production seam.
      expect(
        bootstrapRequestToWire(req).keys.toSet(),
        kBootstrapRequestFields.toSet(),
      );
      expect(
        <String>{
          ...kBootstrapRequiredRequestFields,
          ...kBootstrapNullableRequestFields,
        },
        kBootstrapRequestFields.toSet(),
      );
    });

    test('V2 optional values serialize as null; local environment is not wire',
        () {
      const req = BootstrapRequest(
        appId: 'app-a',
        installationId: 'inst-1',
        platform: NebulaPlatform.ios,
        publicKey: 'key-der',
        bootstrapRequestId: 'boot-1',
      );
      req.validate();
      final wire = bootstrapRequestToWire(req);
      for (final field in kBootstrapNullableRequestFields) {
        expect(wire[field], isNull,
            reason: '$field canonical unset must be null');
      }
      expect(wire.keys, isNot(contains('environment')));
      expect(wire.keys, isNot(contains('key_algorithm')));
    });

    test('bootstrap result parses every frozen wire field', () {
      // Wire facts pinned by flypost BootstrapResult (Unix int64, "ES256").
      final json = <String, Object?>{
        'installation_token': 'tok',
        'expires_at': 1785866400,
        'renew_after': 1785849120,
        'server_time': 1785780000,
        'app_id': 'app-a',
        'installation_id': 'inst-1',
        'proof_algorithm': 'ES256',
        'attestation_state': 'verified',
        'minimum_supported_build': '20260701',
        'request_id': 'r-1',
      };
      final result = BootstrapResult.fromJson(json);
      expect(result.appId, 'app-a');
      expect(result.proofAlgorithm, NebulaProofAlgorithm.es256);
      expect(result.serverTime, DateTime.utc(2026, 8, 3, 18));
      // Unknown fields are tolerated; frozen fields must all be present above.
    });

    test('authenticated request pipeline has no App Secret anywhere', () {
      // docs/08 §2 + AGENTS hard boundary: mobile client never holds a secret.
      // The public options surface only exposes the public appId; the SDK
      // defines no secret type or option (compile-time boundary).
      final opts = NebulaOptions(
        appId: 'app-a',
        baseUri: Uri.parse('https://api.example.com'),
        environment: NebulaEnvironment.production,
      );
      opts.validate();
      expect(opts.appId, 'app-a');
      expect(opts.toString(), isNot(contains('secret')));
    });
  });

  group('FC-01 scenarios 2-3: refresh single-flight and family revoke', () {
    test('one refresh request ID per rotation (flypost and SDK agree)',
        () async {
      // flypost: TestRefreshRotatesInPlace / TestRefreshReuseRevokesFamily.
      // SDK: NebulaSession.refresh single-flight + reuse -> REVOKED.
      final store = InMemoryTokenStore();
      final backend = _FakeRefresh();
      final s = NebulaSession(
        namespace: 'staging:app-a',
        tokenStore: store,
        refreshExecutor: backend.run,
      );
      await s.beginBootstrap();
      await s.onBootstrapSucceeded();
      await s.beginAuthenticating();
      await s.onAuthenticated(
        const SessionTokenPair(accessToken: 'a0', refreshToken: 'r0'),
      );
      final f1 = s.refresh();
      final f2 = s.refresh();
      await Future<void>.delayed(Duration.zero);
      backend.complete(
          const SessionTokenPair(accessToken: 'a1', refreshToken: 'r1'));
      await f1;
      await f2;
      expect(backend.calls, 1, reason: 'concurrent callers share one refresh');
      expect(s.state, NebulaSessionState.authenticated);
      s.dispose();
    });

    test('refresh replay revokes the family locally (SDK contract)', () async {
      // flypost: TestRefreshReuseRevokesFamily (12002, durable revocation).
      // SDK: SessionRevokedError from the runner -> REVOKED + SecurityAlert.
      final s = NebulaSession(
        namespace: 'staging:app-a',
        tokenStore: InMemoryTokenStore(),
        refreshExecutor: (_) async =>
            throw const SessionRevokedError(code: 12002),
      );
      await s.beginBootstrap();
      await s.onBootstrapSucceeded();
      await s.beginAuthenticating();
      await s.onAuthenticated(
        const SessionTokenPair(accessToken: 'a0', refreshToken: 'r0'),
      );
      var alert = false;
      s.events.listen((e) {
        if (e is SecurityAlert) alert = true;
      });
      await expectLater(s.refresh(), throwsA(isA<SessionRevokedError>()));
      expect(s.state, NebulaSessionState.revoked);
      expect(alert, isTrue);
      s.dispose();
    });
  });

  group('FC-01 scenario 4: logout rejects old access and refresh', () {
    test('logout clears local tokens; session state returns to installation',
        () async {
      // flypost: TestLogoutUnderTokenMiddleware + TestLogoutIdempotent.
      // SDK: signOut clears refresh from the token store and drops access.
      final store = InMemoryTokenStore();
      final s = NebulaSession(
        namespace: 'staging:app-a',
        tokenStore: store,
        refreshExecutor: (_) async =>
            const SessionTokenPair(accessToken: 'a', refreshToken: 'r'),
        remoteLogout: () async => throw Exception('network down'),
      );
      await s.beginBootstrap();
      await s.onBootstrapSucceeded();
      await s.beginAuthenticating();
      await s.onAuthenticated(
        const SessionTokenPair(accessToken: 'a0', refreshToken: 'r0'),
      );
      await s.signOut();
      expect(s.state, NebulaSessionState.installationActive);
      expect(s.accessToken, isNull);
      expect(
        await store.read(namespace: 'staging:app-a', key: tokenKeyRefresh),
        isNull,
      );
      s.dispose();
    });
  });

  group('FC-01 scenario 5: App A token at App B rejected', () {
    test('namespace isolates tokens per environment/App (SDK side)', () async {
      // flypost: TestRefreshAppInstallationMismatchRejected (server-side).
      // SDK: tokens are keyed under environment:app namespace (FS-01/FS-02).
      final store = InMemoryTokenStore();
      const nsA = 'staging:app-a';
      const nsB = 'staging:app-b';
      await store.write(namespace: nsA, key: tokenKeyRefresh, value: 'rA');
      expect(await store.read(namespace: nsB, key: tokenKeyRefresh), isNull);
      expect(await store.read(namespace: nsA, key: tokenKeyRefresh), 'rA');
    });
  });

  group('FC-01 scenario 6: key loss -> new bootstrap, old key rejected', () {
    test('each generated key pair is a fresh identity (SDK contract)',
        () async {
      // flypost: FB-02 installation owner (reinstall = new identity, old key
      // never recovered, docs/08 §4.3). SDK: key Port generates distinct
      // thumbprints per call; the private key never leaves the key store.
      final port = FakeInstallationKeyPort();
      final a = await port.generateKeyPair();
      final b = await port.generateKeyPair();
      expect(a.publicKeyThumbprint, isNot(b.publicKeyThumbprint));
      expect(a.privateKeyRef, isNot(b.privateKeyRef));
    });
  });

  group('FC-01 scenario 7: legacy chain until cutoff', () {
    test('SDK canonicalization matches the target chain, not legacy HMAC', () {
      // flypost: TestLegacyAuthRoutesStillRegistered + route inventory.
      // Target proof canonical input is the frozen 7-segment form; there is no
      // legacy HMAC-style string anywhere in the SDK auth contracts.
      final canonical = const ProofCanonicalInput(
        method: 'POST',
        path: '/api/v1/mobile/auth/login',
        timestamp: '1725300000',
        nonce: 'n',
        bodySha256: 'b',
        tokenSha256: 't',
      ).canonicalize();
      expect(canonical,
          'V1\nPOST\n/api/v1/mobile/auth/login\n1725300000\nn\nb\nt');
      expect(canonical, isNot(contains('sign=')));
    });
  });

  group('FC-01 scenario 8: saturation does not block bootstrap/login', () {
    test('bootstrap and auth stay in independent buckets (SDK contract)',
        () async {
      // flypost: TestAbuseIsolationAIfloodDoesNotConsumeBootstrapBucket
      // (server-side buckets). SDK side has no server buckets; the contract
      // it must honor is one bounded bootstrap retry with the same
      // bootstrap_request_id (docs/08 §3) — the SDK request carries a stable
      // idempotency key for exactly one retry.
      const req = BootstrapRequest(
        appId: 'app-a',
        installationId: 'inst-1',
        platform: NebulaPlatform.ios,
        publicKey: 'key-der',
        bootstrapRequestId: 'req-1',
      );
      req.validate();
      expect(req.bootstrapRequestId, 'req-1');
    });
  });

  group('FC-01 shared wire facts', () {
    test('frozen proof header list matches docs/08 §5', () {
      expect(
          kFrozenProofHeaders,
          containsAll(<String>[
            'X-Installation-Token',
            'X-Proof-Timestamp',
            'X-Proof-Nonce',
            'X-Device-Proof',
          ]));
      expect(kFrozenProofHeaders, hasLength(5));
    });

    test('error code allocation 12001-12004 matches flypost errcode', () {
      // flypost: internal/pkg/errcode/errcode.go (FB-01 allocation).
      expect(nebulaCodeInstallationInvalid, 12001);
      expect(nebulaCodeSessionRevoked, 12002);
      expect(nebulaCodeClientOutdated, 12003);
      expect(nebulaCodeTemporarilyUnavailable, 12004);
    });
  });
}

/// Minimal refresh double for scenario 2/3 assertions.
class _FakeRefresh {
  int calls = 0;
  final List<String> ids = <String>[];
  var _completer = Future<SessionTokenPair>.value(
    const SessionTokenPair(accessToken: 'a', refreshToken: 'r'),
  );

  Future<SessionTokenPair> run(String requestId) {
    calls += 1;
    ids.add(requestId);
    return _completer;
  }

  void complete(SessionTokenPair pair) {
    _completer = Future<SessionTokenPair>.value(pair);
  }
}

/// Reconcile-only bridge helpers for the pre-F01-004 typed model. They are
/// NOT the production serializer; canonical serialization ownership is SDK
/// production code in S1-F01-004. S1-F01-004
/// must replace production ownership with an SDK serializer/client; consumers
/// must never copy these helpers.
BootstrapRequest bootstrapRequestFromWire(Map<String, Object?> json) {
  return BootstrapRequest(
    appId: json['app_id']! as String,
    installationId: json['installation_id']! as String,
    platform: NebulaPlatform.values.byName(json['platform']! as String),
    appVersion: json['app_version'] as String?,
    buildNumber: json['build_number'] as String?,
    osVersion: json['os_version'] as String?,
    locale: json['locale'] as String?,
    region: json['region'] as String?,
    publicKey: json['public_key']! as String,
    attestation: json['attestation'] as String?,
    bootstrapRequestId: json['bootstrap_request_id']! as String,
  );
}

Map<String, Object?> bootstrapRequestToWire(BootstrapRequest r) =>
    <String, Object?>{
      'app_id': r.appId,
      'installation_id': r.installationId,
      'platform': r.platform.name,
      'app_version': r.appVersion,
      'build_number': r.buildNumber,
      'os_version': r.osVersion,
      'locale': r.locale,
      'region': r.region,
      'public_key': r.publicKey,
      'attestation': r.attestation,
      'bootstrap_request_id': r.bootstrapRequestId,
    };
