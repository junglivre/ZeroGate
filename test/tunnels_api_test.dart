import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerogate/data/tunnels_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'cf_api_token': 'test-token'});
  });

  test('getTunnelConfig reads and returns the remote config', () async {
    await http.runWithClient(
      () async {
        final config =
            await TunnelsApi.getTunnelConfig('account-id', 'tunnel-id');

        expect(config, {
          'originRequest': {'connectTimeout': 30},
          'ingress': [
            {'hostname': 'app.example.com', 'service': 'http://localhost:8080'},
          ],
        });
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/client/v4/accounts/account-id/cfd_tunnel/tunnel-id/configurations',
        );
        return http.Response(
          jsonEncode({
            'success': true,
            'result': {
              'config': {
                'originRequest': {'connectTimeout': 30},
                'ingress': [
                  {
                    'hostname': 'app.example.com',
                    'service': 'http://localhost:8080',
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );
  });

  test('saveTunnelConfig sends the complete config in a PUT', () async {
    final config = {
      'originRequest': {'connectTimeout': 30},
      'warp-routing': {'enabled': true},
      'ingress': [
        {'hostname': 'app.example.com', 'service': 'http://localhost:8080'},
        {'service': 'http_status:503'},
      ],
    };

    await http.runWithClient(
      () => TunnelsApi.saveTunnelConfig('account-id', 'tunnel-id', config),
      () => MockClient((request) async {
        expect(request.method, 'PUT');
        expect(
          request.url.path,
          '/client/v4/accounts/account-id/cfd_tunnel/tunnel-id/configurations',
        );
        expect(jsonDecode(request.body), {'config': config});
        return http.Response(jsonEncode({'success': true, 'result': {}}), 200);
      }),
    );
  });
}
