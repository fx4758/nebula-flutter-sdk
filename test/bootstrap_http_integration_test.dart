import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

import 'bootstrap_test_support.dart';

void main() {
  test('real HttpTransport sends canonical bootstrap wire and parses envelope',
      () async {
    final BootstrapRequest request = fixtureBootstrapRequest(
      populatedOptionals: false,
    );
    final HttpServer server = await HttpServer.bind('127.0.0.1', 0);
    late Map<String, Object?> observedBody;
    late String observedPath;
    late String observedMethod;

    server.listen((HttpRequest incoming) async {
      observedPath = incoming.uri.path;
      observedMethod = incoming.method;
      observedBody = jsonDecode(await utf8.decoder.bind(incoming).join())
          as Map<String, Object?>;
      incoming.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<String, Object?>{
          'code': 0,
          'data': bootstrapSuccessData(request),
        }));
      await incoming.response.close();
    });

    try {
      final HttpTransport transport = HttpTransport(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final BootstrapResult result =
          await NebulaBootstrapClient(transport: transport).bootstrap(request);

      expect(observedMethod, 'POST');
      expect(observedPath, BootstrapEndpoints.bootstrap);
      expect(observedBody, request.toJson());
      expect(observedBody, hasLength(11));
      expect(observedBody['app_version'], isNull);
      expect(observedBody['attestation'], isNull);
      expect(result.requestId, request.bootstrapRequestId);
    } finally {
      await server.close(force: true);
    }
  });
}
