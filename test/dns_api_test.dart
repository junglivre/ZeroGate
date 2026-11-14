import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerogate/data/dns_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'cf_api_token': 'test-token'});
  });

  test('listZones sends the account filter', () async {
    await http.runWithClient(
      () async {
        expect(await DnsApi.listZones('account-id'), [
          {'id': 'zone-id', 'name': 'example.com'},
        ]);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/client/v4/zones');
        expect(request.url.queryParameters['account.id'], 'account-id');
        return http.Response(
            jsonEncode({
              'success': true,
              'result': [
                {'id': 'zone-id', 'name': 'example.com'},
              ],
              'result_info': {'total_pages': 1},
            }),
            200);
      }),
    );
  });

  test('listRecords sends the requested filters', () async {
    await http.runWithClient(
      () async {
        await DnsApi.listRecords(
          'zone-id',
          filters: {'name.exact': 'app.example.com', 'type': 'CNAME'},
        );
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/client/v4/zones/zone-id/dns_records');
        expect(request.url.queryParameters['name.exact'], 'app.example.com');
        expect(request.url.queryParameters['type'], 'CNAME');
        return http.Response(
            jsonEncode({
              'success': true,
              'result': [],
              'result_info': {'total_pages': 1},
            }),
            200);
      }),
    );
  });

  test('record writes use their expected methods, paths, and body', () async {
    final record = {
      'type': 'CNAME',
      'name': 'app.example.com',
      'content': 'tunnel-id.cfargotunnel.com',
      'proxied': true,
      'ttl': 1,
    };
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await DnsApi.createRecord('zone-id', record);
        await DnsApi.updateRecord('zone-id', 'record-id', record);
        await DnsApi.deleteRecord('zone-id', 'record-id');
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'success': true, 'result': {}}), 200);
      }),
    );

    expect(
        requests.map((request) => request.method), ['POST', 'PUT', 'DELETE']);
    expect(requests[0].url.path, '/client/v4/zones/zone-id/dns_records');
    expect(
        requests[1].url.path, '/client/v4/zones/zone-id/dns_records/record-id');
    expect(
        requests[2].url.path, '/client/v4/zones/zone-id/dns_records/record-id');
    expect(jsonDecode(requests[0].body), record);
    expect(jsonDecode(requests[1].body), record);
  });

  test('Cloudflare API error responses become exceptions', () async {
    await http.runWithClient(
      () => expectLater(
        DnsApi.createRecord('zone-id', const {}),
        throwsA(predicate((error) => '$error'.contains('record rejected'))),
      ),
      () => MockClient((_) async => http.Response(
          jsonEncode({
            'success': false,
            'errors': [
              {'message': 'record rejected'},
            ],
          }),
          200)),
    );
  });
}
