import 'package:zerogate/data/ingress_rule_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateHostname', () {
    test('rejects empty hostname', () {
      expect(IngressRuleValidator.validateHostname(''), isNotNull);
      expect(IngressRuleValidator.validateHostname('   '), isNotNull);
    });

    test('rejects hostname with spaces', () {
      expect(IngressRuleValidator.validateHostname('app example.com'), isNotNull);
    });

    test('rejects malformed hostnames', () {
      expect(IngressRuleValidator.validateHostname('not-a-domain'), isNotNull);
      expect(IngressRuleValidator.validateHostname('-bad.example.com'), isNotNull);
    });

    test('accepts a valid hostname', () {
      expect(IngressRuleValidator.validateHostname('app.example.com'), isNull);
      expect(IngressRuleValidator.validateHostname('APP.Example.com'), isNull);
    });
  });

  group('validateAddress', () {
    test('rejects empty address', () {
      expect(IngressRuleValidator.validateAddress('http', ''), isNotNull);
    });

    test('rejects an address that still includes a scheme', () {
      expect(IngressRuleValidator.validateAddress('http', 'http://localhost:8080'),
          isNotNull);
    });

    test('requires an absolute path for unix sockets', () {
      expect(IngressRuleValidator.validateAddress('unix', 'app.sock'), isNotNull);
      expect(IngressRuleValidator.validateAddress('unix', '/var/run/app.sock'), isNull);
      expect(
          IngressRuleValidator.validateAddress('unix+tls', '/var/run/app.sock'), isNull);
    });

    test('accepts host:port addresses for network schemes', () {
      expect(IngressRuleValidator.validateAddress('http', 'localhost:8080'), isNull);
      expect(IngressRuleValidator.validateAddress('https', '10.0.0.5:443'), isNull);
      expect(IngressRuleValidator.validateAddress('tcp', 'localhost:22'), isNull);
      expect(IngressRuleValidator.validateAddress('ssh', '10.0.0.5:22'), isNull);
      expect(IngressRuleValidator.validateAddress('rdp', '10.0.0.5:3389'), isNull);
    });
  });

  group('buildService / parseService', () {
    test('builds and round-trips network schemes', () {
      final service = IngressRuleValidator.buildService('http', 'localhost:8080');
      expect(service, 'http://localhost:8080');
      final parsed = IngressRuleValidator.parseService(service);
      expect(parsed.scheme, 'http');
      expect(parsed.address, 'localhost:8080');
    });

    test('builds and round-trips unix socket schemes', () {
      final service = IngressRuleValidator.buildService('unix', '/var/run/app.sock');
      expect(service, 'unix:/var/run/app.sock');
      final parsed = IngressRuleValidator.parseService(service);
      expect(parsed.scheme, 'unix');
      expect(parsed.address, '/var/run/app.sock');
    });

    test('falls back to http for an unrecognized legacy format', () {
      final parsed = IngressRuleValidator.parseService('localhost:8080');
      expect(parsed.scheme, 'http');
      expect(parsed.address, 'localhost:8080');
    });
  });

  group('validatePositiveInt', () {
    test('accepts empty (means "not set")', () {
      expect(IngressRuleValidator.validatePositiveInt(''), isNull);
    });

    test('accepts non-negative integers', () {
      expect(IngressRuleValidator.validatePositiveInt('0'), isNull);
      expect(IngressRuleValidator.validatePositiveInt('30'), isNull);
    });

    test('rejects non-numeric or negative values', () {
      expect(IngressRuleValidator.validatePositiveInt('abc'), isNotNull);
      expect(IngressRuleValidator.validatePositiveInt('-1'), isNotNull);
    });
  });
}
