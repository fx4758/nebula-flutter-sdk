import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// FC-02 — Cross-repo runtime-config contract fixtures (docs/12 §11)
//
// Contract artifacts only: this file does NOT add production implementation.
// It pins the SDK runtime-config fixtures to the frozen wire contract
// (docs/12 §4/§7/§8) and to the flypost FB-06 anchors:
//   - internal/module/runtimeconfig/   (dto/service/handler — snapshot shape,
//     caps, version policy, kill switch)
//   - internal/router/runtime_config_http_test.go (ETag/304, forced_upgrade,
//     kill switch HTTP evidence)
//   - sdk/CONTRACT.md §4.7             (flypost-side contract mirror)
//   - internal/pkg/errcode/errcode.go  (12001-12004/40002/50001/30001)
//
// Boundary (F2-01): client-model 1:1 mapping (NebulaEffectiveConfig) and the
// cache behaviors (stale-if-error, security-critical no-stale, single-flight)
// are implemented and tested in F2-01, which consumes these fixtures.
// =============================================================================

Map<String, Object?> _rcFixture(String name) {
  final raw =
      File('test/fixtures/runtime_config/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

Map<String, Object?> _errorMapping() =>
    jsonDecode(File('test/fixtures/error_mapping.json').readAsStringSync())
        as Map<String, Object?>;

/// Frozen snapshot top-level fields (docs/12 §4).
const List<String> kSnapshotFields = <String>[
  'revision',
  'server_time',
  'configs',
  'features',
  'version_policy',
  'cache_policy',
];

const List<String> kVersionPolicyFields = <String>[
  'minimum_supported_build',
  'latest_build',
  'action',
  'message_key',
];

const List<String> kCachePolicyFields = <String>[
  'ttl_seconds',
  'stale_if_error_seconds',
];

const List<String> kFeatureActions = <String>[
  'none',
  'upgrade',
  'forced_upgrade'
];

/// docs/12 §8.2 forbidden control-plane keys — must never appear anywhere.
const List<String> kForbiddenKeys = <String>[
  'rules_json',
  'rollout_percentage',
  'created_by',
  'updated_by',
  'config_value',
];

/// Client-side hard caps (docs/12 §8.3); the SDK must reject over-limit
/// snapshots as malformed (never partial trust).
const int kMaxConfigItems = 128;
const int kMaxFeatureItems = 256;

void main() {
  group('FC-02 success snapshot fixtures (docs/12 §4)', () {
    test('top-level fields are exactly the frozen set', () {
      for (final name in <String>[
        'success_snapshot',
        'version_policy_forced_upgrade',
        'version_policy_upgrade',
        'version_policy_none',
      ]) {
        final json = _rcFixture(name);
        expect(json['code'], 0, reason: '$name must be a success envelope');
        final data = json['data']! as Map<String, Object?>;
        expect(data.keys.toSet(), kSnapshotFields.toSet(),
            reason: '$name snapshot fields drift');
        // Each section has exactly its frozen keys.
        final vp = data['version_policy']! as Map<String, Object?>;
        expect(vp.keys.toSet(), kVersionPolicyFields.toSet(),
            reason: '$name version_policy drift');
        final cp = data['cache_policy']! as Map<String, Object?>;
        expect(cp.keys.toSet(), kCachePolicyFields.toSet(),
            reason: '$name cache_policy drift');
        for (final f
            in (data['features']! as List).cast<Map<String, Object?>>()) {
          final extra = f.keys.where(
              (k) => k != 'key' && k != 'enabled' && k != 'security_critical');
          expect(extra, isEmpty,
              reason: '$name feature has extra fields: $extra');
        }
        for (final entry
            in (data['configs']! as Map<String, Object?>).entries) {
          final item = entry.value as Map<String, Object?>;
          final extra =
              item.keys.where((k) => k != 'value' && k != 'updated_at');
          expect(extra, isEmpty,
              reason: '$name config item extra fields: $extra');
        }
      }
    });

    test('revision is non-empty and server_time is a positive integer', () {
      final data =
          _rcFixture('success_snapshot')['data']! as Map<String, Object?>;
      expect(data['revision'], isNotEmpty);
      expect(data['server_time'] is int && (data['server_time']! as int) > 0,
          isTrue);
    });

    test('control-plane fields never appear anywhere in a snapshot', () {
      for (final name in <String>[
        'success_snapshot',
        'version_policy_forced_upgrade',
        'version_policy_upgrade',
        'version_policy_none',
        'over_limit_snapshot',
      ]) {
        final raw =
            File('test/fixtures/runtime_config/$name.json').readAsStringSync();
        for (final forbidden in kForbiddenKeys) {
          expect(raw.contains(forbidden), isFalse,
              reason: '$name leaks control-plane field $forbidden');
        }
      }
    });

    test('success snapshot decodes through the transport envelope', () {
      final json = _rcFixture('success_snapshot');
      final ApiEnvelope env = ApiEnvelope.decode(json);
      expect(env.isSuccess, isTrue);
      final data = env.data! as Map<String, Object?>;
      expect(data['revision'], isNotEmpty);
    });
  });

  group('FC-02 version policy scenarios (docs/12 §5)', () {
    test('three action fixtures carry their frozen action', () {
      const cases = <String, String>{
        'version_policy_forced_upgrade': 'forced_upgrade',
        'version_policy_upgrade': 'upgrade',
        'version_policy_none': 'none',
      };
      cases.forEach((name, action) {
        final data = _rcFixture(name)['data']! as Map<String, Object?>;
        final vp = data['version_policy']! as Map<String, Object?>;
        expect(vp['action'], action, reason: '$name action mismatch');
        expect(kFeatureActions, contains(vp['action']));
        expect(vp['minimum_supported_build'] is int, isTrue);
        expect(vp['latest_build'] is int, isTrue);
      });
    });
  });

  group('FC-02 error fixtures (docs/12 §7)', () {
    test('every runtime-config error code is frozen in error_mapping', () {
      final table = (_errorMapping()['runtime_config']! as List)
          .cast<Map<String, Object?>>();
      final mapped = table.map((r) => r['code']! as int).toSet();
      for (final code in <int>[12001, 12003, 12004, 40002, 50001]) {
        expect(mapped, contains(code),
            reason:
                'code $code must be registered in error_mapping.runtime_config');
      }
    });

    test('error fixtures are valid envelopes with non-zero frozen codes', () {
      for (final code in <int>[12001, 12003, 12004, 40002, 50001]) {
        final json = _rcFixture('error_$code');
        expect(json['code'], code);
        expect(json.containsKey('data'), isTrue);
        expect(json.containsKey('msg'), isFalse,
            reason: 'envelope must not carry msg (docs/08 §8)');
      }
    });

    test('classifiers map runtime-config codes to recoverable categories', () {
      // General classifier (F1-04): coarse categories for logging/handling.
      expect(classifyNebulaError(const NebulaApiException('x', code: 12004)),
          NebulaErrorCategory.temporarilyUnavailable);
      expect(classifyNebulaError(const NebulaApiException('x', code: 50001)),
          NebulaErrorCategory.server);
      expect(classifyNebulaError(const NebulaApiException('x', code: 40002)),
          NebulaErrorCategory.rateLimited);
      // Session classifier keeps typed errors + requestId for auth flows.
      expect(classifySessionError(statusCode: 200, code: 12004),
          isA<TemporarilyUnavailableError>());
      expect(
        classifySessionError(statusCode: 200, code: 50001),
        isA<AuthenticationRequiredError>(), // session fallback, documented
      );
    });

    test('kill-switch delivery-disabled is a classified, non-fatal error', () {
      // docs/12 §8.6: 12004 must be a categorized error the client can
      // back off from — never a crash, never a cached disabled state.
      final NebulaApiException e =
          const NebulaApiException('delivery disabled', code: 12004);
      expect(
          classifyNebulaError(e), NebulaErrorCategory.temporarilyUnavailable);
      expect(e.code, 12004);
    });
  });

  group('FC-02 client cap contract (docs/12 §8.3)', () {
    test('over-limit fixture is flagged by the frozen client-side rule', () {
      final data =
          _rcFixture('over_limit_snapshot')['data']! as Map<String, Object?>;
      final configs = data['configs']! as Map<String, Object?>;
      expect(configs.length, greaterThan(kMaxConfigItems),
          reason: 'fixture must exceed the 128-item cap to be meaningful');
      expect(_exceedsLimits(data), isTrue,
          reason: 'client MUST reject over-limit snapshots as malformed');
    });

    test('in-limit fixture passes the client-side rule', () {
      final data =
          _rcFixture('success_snapshot')['data']! as Map<String, Object?>;
      expect(_exceedsLimits(data), isFalse);
    });
  });
}

/// Frozen client-side limit check (docs/12 §8.3). F2-01's parser MUST reject
/// snapshots for which this returns true (treated as malformed, never
/// partially trusted). Kept here as the contract's executable definition.
bool _exceedsLimits(Map<String, Object?> data) {
  final configs = data['configs']! as Map<String, Object?>;
  if (configs.length > kMaxConfigItems) return true;
  final features = data['features']! as List;
  if (features.length > kMaxFeatureItems) return true;
  return false;
}
