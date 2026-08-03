import '../lib/nebula_sdk.dart';

void main() {
  final NebulaOptions options = NebulaOptions(
    appId: 'smoke-app',
    baseUri: Uri(scheme: 'https', host: 'api.example.com'),
    environment: NebulaEnvironment.production,
  );
  options.validate();
}
