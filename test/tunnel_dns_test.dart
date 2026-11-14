import 'package:flutter_test/flutter_test.dart';
import 'package:zerogate/data/tunnel_dns.dart';

void main() {
  const tunnelId = '12345678-1234-1234-1234-123456789abc';

  group('zoneFor', () {
    final zones = [
      {'id': 'example', 'name': 'example.com'},
      {'id': 'dev', 'name': 'dev.example.com'},
    ];

    test('chooses the most specific matching suffix', () {
      expect(TunnelDns.zoneFor('app.dev.example.com', zones)?['id'], 'dev');
    });

    test('matches only on a label boundary', () {
      expect(TunnelDns.zoneFor('notexample.com', zones), isNull);
    });

    test('matches the zone apex', () {
      expect(TunnelDns.zoneFor('example.com', zones)?['id'], 'example');
    });

    test('matches a wildcard hostname against its zone', () {
      expect(TunnelDns.zoneFor('*.example.com', zones)?['id'], 'example');
    });

    test('normalizes uppercase names and trailing dots', () {
      expect(TunnelDns.zoneFor('APP.DEV.EXAMPLE.COM.', zones)?['id'], 'dev');
    });

    test('returns null when no zone matches', () {
      expect(TunnelDns.zoneFor('app.example.net', zones), isNull);
    });
  });

  group('planEnsure', () {
    test('creates when no A, AAAA, or CNAME record exists', () {
      final plan = TunnelDns.planEnsure('app.example.com', tunnelId, []);

      expect(plan, isA<DnsCreatePlan>());
    });

    test('does nothing for a proxied CNAME to the tunnel', () {
      final plan = TunnelDns.planEnsure('app.example.com', tunnelId, [
        {
          'type': 'CNAME',
          'content': '$tunnelId.CFARGOTUNNEL.COM.',
          'proxied': true,
        },
      ]);

      expect(plan, isA<DnsNoopPlan>());
    });

    test('updates an unproxied CNAME to the tunnel', () {
      final record = {
        'type': 'CNAME',
        'content': TunnelDns.target(tunnelId),
        'proxied': false,
      };
      final plan = TunnelDns.planEnsure('app.example.com', tunnelId, [record]);

      expect(plan, isA<DnsUpdatePlan>());
      expect((plan as DnsUpdatePlan).record, same(record));
    });

    test('reports one other CNAME or A record as a conflict', () {
      for (final record in [
        {'type': 'CNAME', 'content': 'other.cfargotunnel.com'},
        {'type': 'A', 'content': '192.0.2.1'},
      ]) {
        final plan =
            TunnelDns.planEnsure('app.example.com', tunnelId, [record]);

        expect(plan, isA<DnsConflictPlan>());
        expect((plan as DnsConflictPlan).record, same(record));
      }
    });

    test('blocks when multiple A, AAAA, or CNAME records exist', () {
      final records = [
        {'type': 'A', 'content': '192.0.2.1'},
        {'type': 'A', 'content': '192.0.2.2'},
      ];
      final plan = TunnelDns.planEnsure('app.example.com', tunnelId, records);

      expect(plan, isA<DnsBlockedPlan>());
      expect((plan as DnsBlockedPlan).records, records);
    });

    test('ignores TXT and MX records at the same hostname', () {
      final plan = TunnelDns.planEnsure('app.example.com', tunnelId, [
        {'type': 'TXT', 'content': 'verification'},
        {'type': 'MX', 'content': 'mail.example.com'},
      ]);

      expect(plan, isA<DnsCreatePlan>());
    });
  });

  group('shouldDelete', () {
    final record = {
      'type': 'CNAME',
      'content': TunnelDns.target(tunnelId),
    };

    test('deletes an unshared CNAME pointing to the tunnel', () {
      expect(
        TunnelDns.shouldDelete(record, tunnelId, 'app.example.com', []),
        isTrue,
      );
    });

    test('keeps a CNAME shared by another remaining route', () {
      expect(
        TunnelDns.shouldDelete(record, tunnelId, 'app.example.com', [
          {'hostname': 'APP.EXAMPLE.COM.'},
        ]),
        isFalse,
      );
    });

    test('keeps a CNAME for another tunnel', () {
      expect(
        TunnelDns.shouldDelete(
          {'type': 'CNAME', 'content': 'other.cfargotunnel.com'},
          tunnelId,
          'app.example.com',
          [],
        ),
        isFalse,
      );
    });

    test('keeps a non-CNAME record', () {
      expect(
        TunnelDns.shouldDelete(
          {'type': 'A', 'content': '192.0.2.1'},
          tunnelId,
          'app.example.com',
          [],
        ),
        isFalse,
      );
    });
  });

  group('deriveStatus', () {
    final routes = [
      {'hostname': 'app.example.com'},
      {'hostname': 'missing.example.com'},
    ];
    final zones = [
      {'id': 'example', 'name': 'example.com'},
    ];

    test('rebuilds state after a zone read succeeds', () {
      final failed = TunnelDns.deriveStatus(
        routes,
        zones,
        const {},
        {'example'},
      );
      expect(failed.statuses, {
        'app.example.com': DnsStatus.unknown,
        'missing.example.com': DnsStatus.unknown,
      });
      expect(failed.orphanRecords, isEmpty);

      final current = TunnelDns.deriveStatus(
        routes,
        zones,
        {
          'example': [
            {'name': 'app.example.com', 'proxied': true},
            {'name': 'old.example.com', 'proxied': true},
          ],
        },
        const {},
      );
      expect(current.statuses, {
        'app.example.com': DnsStatus.ok,
        'missing.example.com': DnsStatus.missing,
      });
      expect(current.orphanRecords, [
        {'name': 'old.example.com', 'proxied': true, 'zoneId': 'example'},
      ]);
    });
  });
}
