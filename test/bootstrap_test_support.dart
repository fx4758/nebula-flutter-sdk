import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';

Map<String, Object?> bootstrapFixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, Object?>;

String get fixtureP256PublicKey =>
    bootstrapFixture('bootstrap_request')['public_key']! as String;

BootstrapRequest fixtureBootstrapRequest({
  String? appId,
  String? installationId,
  String? bootstrapRequestId,
  String? publicKey,
  String? appVersion,
  String? buildNumber,
  String? osVersion,
  String? locale,
  String? region,
  String? attestation,
  bool populatedOptionals = true,
}) {
  final Map<String, Object?> f = bootstrapFixture('bootstrap_request');
  return BootstrapRequest(
    appId: appId ?? f['app_id']! as String,
    installationId: installationId ?? f['installation_id']! as String,
    platform: NebulaPlatform.values.byName(f['platform']! as String),
    publicKey: publicKey ?? fixtureP256PublicKey,
    bootstrapRequestId:
        bootstrapRequestId ?? f['bootstrap_request_id']! as String,
    appVersion:
        appVersion ?? (populatedOptionals ? f['app_version'] as String? : null),
    buildNumber: buildNumber ??
        (populatedOptionals ? f['build_number'] as String? : null),
    osVersion:
        osVersion ?? (populatedOptionals ? f['os_version'] as String? : null),
    locale: locale ?? (populatedOptionals ? f['locale'] as String? : null),
    region: region ?? (populatedOptionals ? f['region'] as String? : null),
    attestation: attestation ??
        (populatedOptionals ? f['attestation'] as String? : null),
  );
}

Map<String, Object?> bootstrapSuccessData(BootstrapRequest request) =>
    <String, Object?>{
      'installation_token': 'installation-token',
      'expires_at': 1785866400,
      'renew_after': 1785849120,
      'server_time': 1785780000,
      'app_id': request.appId,
      'installation_id': request.installationId,
      'proof_algorithm': 'ES256',
      'attestation_state': 'not_supported',
      'minimum_supported_build': null,
      'request_id': request.bootstrapRequestId,
    };
