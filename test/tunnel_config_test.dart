import 'package:flutter_test/flutter_test.dart';
import 'package:zerogate/data/tunnel_config.dart';

void main() {
  const routeA = {'hostname': 'a.example.com', 'service': 'http://a:8080'};
  const routeB = {'hostname': 'b.example.com', 'service': 'http://b:8080'};
  const catchAll = {'service': 'http_status:503'};

  group('upsert', () {
    test('inserts a new route before a final catch-all', () {
      final result = TunnelConfig.upsert([routeA, catchAll], rule: routeB);

      expect(result, [routeA, routeB, catchAll]);
    });

    test('adds to an empty list or a list without a catch-all', () {
      expect(TunnelConfig.upsert([], rule: routeA), [routeA]);
      expect(TunnelConfig.upsert([routeA], rule: routeB), [routeA, routeB]);
    });

    test('replaces the original rule in place and keeps path-only rules', () {
      final original = {
        'hostname': 'App.Example.com.',
        'service': 'http://old:8080',
        'path': '/api',
      };
      final replacement = {
        'hostname': 'app.example.com',
        'service': 'http://new:8080',
        'path': '/api',
      };
      final pathOnly = {'path': '/health', 'service': 'http://health:8080'};

      final result = TunnelConfig.upsert(
        [routeA, pathOnly, original, catchAll],
        original: original,
        rule: replacement,
      );

      expect(result, [routeA, pathOnly, replacement, catchAll]);
    });

    test('rejects an original rule changed outside the app', () {
      final original = {
        'hostname': 'app.example.com',
        'service': 'http://app:8080',
        'originRequest': {
          'access': {'required': true}
        },
        'custom': 'original',
      };
      final changedOriginRequest = {
        ...original,
        'originRequest': {
          'access': {'required': false}
        },
      };
      final changedUnknownKey = {...original, 'custom': 'changed'};

      expect(
        () => TunnelConfig.upsert(
          [changedOriginRequest],
          original: original,
          rule: routeB,
        ),
        throwsStateError,
      );
      expect(
        () => TunnelConfig.upsert(
          [changedUnknownKey],
          original: original,
          rule: routeB,
        ),
        throwsStateError,
      );
    });
  });

  test('remove affects only the matching rule when hostnames are shared', () {
    final first = {
      'hostname': 'app.example.com',
      'path': '/one',
      'service': 'http://one:8080',
    };
    final second = {
      'hostname': 'app.example.com',
      'path': '/two',
      'service': 'http://two:8080',
    };

    expect(TunnelConfig.remove([first, second], second), [first]);
    expect(() => TunnelConfig.remove([first], second), throwsStateError);
  });

  group('ensureCatchAll', () {
    test('adds a default catch-all when absent', () {
      expect(
        TunnelConfig.ensureCatchAll([routeA]),
        [
          routeA,
          {'service': 'http_status:404'}
        ],
      );
      expect(
        TunnelConfig.ensureCatchAll([]),
        [
          {'service': 'http_status:404'}
        ],
      );
    });

    test('keeps an existing custom catch-all unchanged', () {
      expect(
          TunnelConfig.ensureCatchAll([routeA, catchAll]), [routeA, catchAll]);
    });
  });

  test('withIngress retains every other tunnel configuration key', () {
    final result = TunnelConfig.withIngress(
      {
        'originRequest': {'connectTimeout': 30},
        'warp-routing': {'enabled': true},
      },
      [routeA, catchAll],
    );

    expect(result['originRequest'], {'connectTimeout': 30});
    expect(result['warp-routing'], {'enabled': true});
    expect(result['ingress'], [routeA, catchAll]);
    expect(TunnelConfig.withIngress(null, [routeA]), {
      'ingress': [routeA]
    });
  });
}
