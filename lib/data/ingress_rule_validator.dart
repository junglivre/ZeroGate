/// Service schemes exposed in the route editor's type selector, matching
/// what `cloudflared` accepts for a tunnel ingress rule's `service` field.
/// (`http_status`, `bastion` and `hello_world` are special-purpose and not
/// offered here — the app manages the catch-all `http_status:404` rule on
/// its own.)
const kIngressServiceSchemes = [
  'http',
  'https',
  'tcp',
  'ssh',
  'rdp',
  'smb',
  'unix',
  'unix+tls',
];

class IngressRuleValidator {
  static String? validateHostname(String hostname) {
    final normalized = hostname.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'O hostname não pode ser vazio.';
    }
    if (normalized.contains(' ')) {
      return 'O hostname não pode conter espaços.';
    }
    if (!_isValidDomainName(normalized)) {
      return 'Informe um hostname válido (ex: app.exemplo.com).';
    }
    return null;
  }

  static bool isUnixScheme(String scheme) {
    return scheme == 'unix' || scheme == 'unix+tls';
  }

  static bool isHttpScheme(String scheme) {
    return scheme == 'http' || scheme == 'https';
  }

  static String? validateAddress(String scheme, String address) {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      return 'O destino não pode ser vazio.';
    }
    if (isUnixScheme(scheme)) {
      if (!normalized.startsWith('/')) {
        return 'Para unix/unix+tls, informe o caminho do socket (ex: /var/run/app.sock).';
      }
      return null;
    }
    if (normalized.contains('://')) {
      return 'Não inclua o esquema aqui — já é definido pelo tipo selecionado.';
    }
    return null;
  }

  /// Builds the full `service` string (e.g. `http://localhost:8080` or
  /// `unix:/var/run/app.sock`) from a scheme + address pair.
  static String buildService(String scheme, String address) {
    final trimmed = address.trim();
    if (isUnixScheme(scheme)) {
      return '$scheme:$trimmed';
    }
    return '$scheme://$trimmed';
  }

  /// Splits an existing `service` string back into scheme + address for
  /// editing. Falls back to `http` if the format isn't recognized (e.g. a
  /// legacy bare `host:port` value with no scheme).
  static ({String scheme, String address}) parseService(String service) {
    for (final scheme in ['unix+tls', 'unix']) {
      final prefix = '$scheme:';
      if (service.startsWith(prefix)) {
        return (scheme: scheme, address: service.substring(prefix.length));
      }
    }
    final match = RegExp(r'^([a-zA-Z0-9+]+)://(.*)$').firstMatch(service);
    if (match != null) {
      return (scheme: match.group(1)!, address: match.group(2)!);
    }
    return (scheme: 'http', address: service);
  }

  static String? validatePositiveInt(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Informe um número inteiro válido.';
    }
    return null;
  }

  static bool _isValidDomainName(String value) {
    var domain = value;
    if (domain.endsWith('.')) {
      domain = domain.substring(0, domain.length - 1);
    }

    if (domain.isEmpty || domain.length > 253 || !domain.contains('.')) {
      return false;
    }

    final labels = domain.split('.');
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return false;
      if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label)) {
        return false;
      }
    }

    return true;
  }
}
