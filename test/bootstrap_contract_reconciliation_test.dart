import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, Object?>;

Set<String> wireKeys(Map<String, Object?> json) =>
    json.keys.where((key) => key != 'comment').toSet();

const requiredRequestFields = <String>{
  'app_id',
  'installation_id',
  'platform',
  'public_key',
  'bootstrap_request_id',
};

const optionalRequestFields = <String>{
  'app_version',
  'build_number',
  'os_version',
  'locale',
  'region',
  'attestation',
};

const responseFields = <String>{
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
};

void main() {
  group('S1-F01-003 bootstrap contract V2 reconciliation', () {
    test('canonical request is five required + six optional = 11 keys', () {
      expect(requiredRequestFields.length, 5);
      expect(optionalRequestFields.length, 6);
      expect(
          requiredRequestFields.intersection(optionalRequestFields), isEmpty);

      final all = {...requiredRequestFields, ...optionalRequestFields};
      expect(all.length, 11);
      expect(wireKeys(fixture('bootstrap_request')), all);
      expect(wireKeys(fixture('bootstrap_request_optional_nulls')), all);
    });

    test('canonical absent optionals are explicit JSON null', () {
      final wire = fixture('bootstrap_request_optional_nulls');
      for (final field in optionalRequestFields) {
        expect(wire[field], isNull, reason: '$field canonical absent value');
      }
      for (final field in requiredRequestFields) {
        expect(wire[field], isNotNull, reason: '$field is required');
      }
    });

    test('paired response echoes bootstrap identity and request id', () {
      final request = fixture('bootstrap_request');
      final response = fixture('bootstrap_response');
      expect(wireKeys(response), responseFields);
      expect(response['app_id'], request['app_id']);
      expect(response['installation_id'], request['installation_id']);
      expect(response['request_id'], request['bootstrap_request_id']);
    });

    test('response timing matches current backend 24h TTL and 80% renew point',
        () {
      final response = fixture('bootstrap_response');
      final serverTime = response['server_time']! as int;
      final renewAfter = response['renew_after']! as int;
      final expiresAt = response['expires_at']! as int;
      expect(expiresAt - serverTime, 24 * 60 * 60);
      expect(renewAfter - serverTime, 69120); // 24h * 0.8 = 19.2h.
      expect(expiresAt - renewAfter, 17280); // remaining 20% = 4.8h.
    });

    test('response wire enums/nullability stay aligned with BootstrapResult',
        () {
      final response = fixture('bootstrap_response');
      final parsed = BootstrapResult.fromJson(response);
      expect(parsed.proofAlgorithm, NebulaProofAlgorithm.es256);
      expect(parsed.attestationState, NebulaAttestationState.notSupported);
      expect(parsed.minimumSupportedBuild, isNull);
    });

    test('machine-readable V2 oracle freezes endpoint, limits and hash scope',
        () {
      final contract = fixture('bootstrap_contract_v2');
      expect(contract['method'], 'POST');
      expect(contract['endpoint'], '/api/v1/mobile/bootstrap');
      expect(contract['body_max_bytes'], 32 * 1024);
      expect(
        (contract['required_request_fields']! as List).toSet(),
        requiredRequestFields,
      );
      expect(
        (contract['optional_request_fields']! as List).toSet(),
        optionalRequestFields,
      );
      expect(contract['canonical_absent_optional'], isNull);
      expect(contract['field_max_utf8_bytes'], <String, Object?>{
        'app_id': 64,
        'installation_id': 64,
        'bootstrap_request_id': 64,
        'app_version': 128,
        'build_number': 128,
        'os_version': 128,
        'locale': 64,
        'region': 64,
        'public_key': 1024,
        'attestation': 16 * 1024,
      });
      expect(
        (contract['platform_values']! as List).toSet(),
        {'ios', 'android', 'harmony', 'web'},
      );
      expect(contract['attestation_wire_type'], 'nullable-string');
      expect(contract['request_id_semantics'], 'echo-bootstrap_request_id');
      expect(
        contract['current_backend_request_hash_fields'],
        <Object?>[
          'resolved_app_id',
          'installation_id',
          'public_key_thumbprint',
          'platform',
          'app_version',
          'build_number',
          'os_version',
        ],
      );
      expect(
        (contract['request_hash_excluded_fields']! as List).toSet(),
        {'locale', 'region', 'attestation'},
      );
    });

    test('machine-readable V2 oracle freezes bounded retry inputs', () {
      final contract = fixture('bootstrap_contract_v2');
      expect(contract['automatic_retry_max'], 1);
      expect(contract['retry_requires_same_request_id_and_values'], isTrue);
      expect(
        (contract['automatic_retry_inputs']! as List).toSet(),
        {
          'transport_ambiguity',
          'http_200_code_50001',
          'http_200_code_12004_if_returned',
        },
      );
      expect(
        (contract['no_immediate_retry_inputs']! as List).toSet(),
        {
          'http_200_code_12001',
          'http_200_code_30001',
          'http_200_code_12003',
          'http_429_code_40002',
          'http_503_code_40002',
        },
      );
    });

    test('machine-readable V2 oracle freezes current HTTP/code outputs', () {
      final contract = fixture('bootstrap_contract_v2');
      final outputs =
          (contract['current_outputs']! as List).cast<Map<String, Object?>>();
      expect(
        outputs.map((row) => (row['http'], row['code'])).toSet(),
        {
          (200, 0),
          (200, 12001),
          (200, 30001),
          (429, 40002),
          (503, 40002),
          (200, 50001),
        },
      );
      expect(
        (contract['allocated_but_not_current_bootstrap_emission']! as List)
            .toSet(),
        {12003, 12004},
      );
    });

    test('current bootstrap emissions are distinct from allocated-only codes',
        () {
      // Backend authority: FlyPostAPI Dev @ 956981c. The 12003/12004 values
      // remain shared mobile allocations but are not emitted by the current
      // bootstrap handler/service path.
      const currentBootstrapBusinessCodes = <int>{
        12001, // installation invalid / validation / app / key / attestation
        30001, // malformed body or idempotency conflict
        50001, // unclassified server/repository failure
      };
      const currentBootstrapMiddlewareCodes = <int>{
        40002, // HTTP 429 limit or HTTP 503 limiter dependency failure
      };
      const allocatedButNotCurrentBootstrapEmission = <int>{12003, 12004};

      expect(currentBootstrapBusinessCodes,
          contains(nebulaCodeInstallationInvalid));
      expect(currentBootstrapBusinessCodes, contains(nebulaCodeParam));
      expect(currentBootstrapMiddlewareCodes, contains(nebulaCodeRateLimited));
      expect(allocatedButNotCurrentBootstrapEmission,
          contains(nebulaCodeClientOutdated));
      expect(allocatedButNotCurrentBootstrapEmission,
          contains(nebulaCodeTemporarilyUnavailable));
      expect(
        currentBootstrapBusinessCodes
            .union(currentBootstrapMiddlewareCodes)
            .intersection(allocatedButNotCurrentBootstrapEmission),
        isEmpty,
      );
    });
  });
}
