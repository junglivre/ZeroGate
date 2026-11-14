import 'package:flutter_test/flutter_test.dart';
import 'package:zerogate/data/route_sync.dart';

const _tunnelId = 'tunnel-id';
const _zone = {'id': 'zone-id', 'name': 'example.com'};
const _route = {
  'hostname': 'app.example.com',
  'service': 'http://localhost:8080',
};

void main() {
  test('create reads DNS before saving ingress and writes DNS afterwards',
      () async {
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      listRecords: (_, {filters = const {}}) async {
        calls.add('listRecords');
        return [];
      },
      createRecord: (_, __) async => calls.add('createRecord'),
    );

    final result = await sync.create(_route, _context());

    expect(result, isA<RouteSaved>());
    expect(calls, ['listRecords', 'loadConfig', 'saveConfig', 'createRecord']);
  });

  test('delete saves ingress before deleting an owned record', () async {
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      config: {
        'ingress': [
          _route,
          {'service': 'http_status:404'}
        ],
      },
      listRecords: (_, {filters = const {}}) async {
        calls.add('listRecords');
        return [
          {
            'id': 'record-id',
            'type': 'CNAME',
            'name': 'app.example.com',
            'content': 'tunnel-id.cfargotunnel.com',
            'proxied': true,
          },
        ];
      },
      deleteRecord: (_, __) async => calls.add('deleteRecord'),
    );

    final result = await sync.delete(_route, _context());

    expect(result, isA<RouteSaved>());
    expect(calls, ['loadConfig', 'saveConfig', 'listRecords', 'deleteRecord']);
  });

  test('editing a hostname creates the new CNAME before removing the old one',
      () async {
    final calls = <String>[];
    const replacement = {
      'hostname': 'new.example.com',
      'service': 'http://localhost:8080',
    };
    final sync = _sync(
      calls: calls,
      config: {
        'ingress': [
          _route,
          {'service': 'http_status:404'}
        ],
      },
      listRecords: (_, {filters = const {}}) async {
        calls.add('list:${filters['name.exact']}');
        if (filters['name.exact'] == 'app.example.com') {
          return [
            {
              'id': 'old-record',
              'type': 'CNAME',
              'name': 'app.example.com',
              'content': 'tunnel-id.cfargotunnel.com',
              'proxied': true,
            },
          ];
        }
        return [];
      },
      createRecord: (_, __) async => calls.add('createRecord'),
      deleteRecord: (_, __) async => calls.add('deleteRecord'),
    );

    final result = await sync.edit(_route, replacement, _context());

    expect(result, isA<RouteSaved>());
    expect(
        calls.indexOf('createRecord'), lessThan(calls.indexOf('deleteRecord')));
  });

  test('fixDns does not save tunnel configuration', () async {
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      listRecords: (_, {filters = const {}}) async => [],
      createRecord: (_, __) async => calls.add('createRecord'),
    );

    final result = await sync.fixDns(_route, _context());

    expect(result, isA<RouteSaved>());
    expect(calls, ['createRecord']);
  });

  test('DNS write failure leaves a saved configuration', () async {
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      listRecords: (_, {filters = const {}}) async => [],
      createRecord: (_, __) async => throw Exception('write failed'),
    );

    final result = await sync.create(_route, _context());

    expect(result, isA<RouteSavedDnsFailed>());
    expect(calls, ['loadConfig', 'saveConfig']);
    expect(result.ingress, isNotNull);
  });

  test('declined DNS conflict does not save configuration', () async {
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      listRecords: (_, {filters = const {}}) async => [
        {
          'id': 'record-id',
          'type': 'A',
          'name': 'app.example.com',
          'content': '192.0.2.1',
        },
      ],
      confirmConflict: (_) async => false,
    );

    final result = await sync.create(_route, _context());

    expect(result, isA<RouteCancelled>());
    expect(calls, isEmpty);
  });

  test('unavailable DNS can save without querying records', () async {
    final calls = <String>[];
    bool? observedUnknown;
    final sync = _sync(
      calls: calls,
      listRecords: (_, {filters = const {}}) async {
        fail('DNS records must not be read when DNS is unavailable');
      },
      confirmNoDns: (_, __, {required bool unknown}) async {
        observedUnknown = unknown;
        return true;
      },
    );

    final result = await sync.create(
      _route,
      const DnsContext(zones: [_zone], tunnelId: _tunnelId, available: false),
    );

    expect(result, isA<RouteSaved>());
    expect(observedUnknown, isTrue);
    expect(calls, ['loadConfig', 'saveConfig']);
  });

  test('deleting one of two saved rules for a hostname keeps its CNAME',
      () async {
    const first = {
      'hostname': 'app.example.com',
      'path': '/one',
      'service': 'http://localhost:8080',
    };
    const second = {
      'hostname': 'app.example.com',
      'path': '/two',
      'service': 'http://localhost:8080',
    };
    final calls = <String>[];
    final sync = _sync(
      calls: calls,
      config: {
        'ingress': [
          first,
          second,
          {'service': 'http_status:404'}
        ],
      },
      listRecords: (_, {filters = const {}}) async => [
        {
          'id': 'record-id',
          'type': 'CNAME',
          'name': 'app.example.com',
          'content': 'tunnel-id.cfargotunnel.com',
          'proxied': true,
        },
      ],
      deleteRecord: (_, __) async => calls.add('deleteRecord'),
    );

    final result = await sync.delete(first, _context());

    expect(result, isA<RouteSaved>());
    expect(calls, ['loadConfig', 'saveConfig']);
  });

  test('external route changes are not overwritten', () async {
    final calls = <String>[];
    final changed = {
      ..._route,
      'originRequest': {'noTLSVerify': true},
    };
    final sync = _sync(
      calls: calls,
      config: {
        'ingress': [
          changed,
          {'service': 'http_status:404'}
        ],
      },
      listRecords: (_, {filters = const {}}) async {
        calls.add('listRecords');
        return [];
      },
    );

    final result = await sync.edit(_route, _route, _context());

    expect(result, isA<RouteChangedElsewhere>());
    expect(calls, ['listRecords', 'loadConfig']);
  });
}

DnsContext _context() => const DnsContext(
      zones: [_zone],
      tunnelId: _tunnelId,
      available: true,
    );

RouteSync _sync({
  required List<String> calls,
  Map<String, dynamic>? config,
  Future<List<dynamic>> Function(String, {Map<String, String> filters})?
      listRecords,
  Future<dynamic> Function(String, Map<String, dynamic>)? createRecord,
  Future<void> Function(String, String)? deleteRecord,
  Future<bool> Function(Map<String, dynamic>)? confirmConflict,
  Future<bool> Function(String, String, {required bool unknown})? confirmNoDns,
}) {
  return RouteSync(
    loadConfig: () async {
      calls.add('loadConfig');
      return config ?? {'ingress': []};
    },
    saveConfig: (_) async => calls.add('saveConfig'),
    listRecords: listRecords ?? (_, {filters = const {}}) async => [],
    createRecord: createRecord ?? (_, __) async {},
    updateRecord: (_, __, ___) async {},
    deleteRecord: deleteRecord ?? (_, __) async {},
    confirmConflict: confirmConflict ?? (_) async => true,
    confirmNoDns: confirmNoDns ?? (_, __, {required unknown}) async => true,
    reportBlocked: (_) async => false,
  );
}
