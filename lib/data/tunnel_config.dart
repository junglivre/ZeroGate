import 'tunnel_dns.dart';

/// Pure helpers for updating one tunnel ingress rule without replacing the
/// rest of its remote configuration.
class TunnelConfig {
  /// Returns whether [rule] is a route that has a non-empty hostname.
  static bool isHostnameRule(Map rule) {
    final hostname = rule['hostname'];
    return hostname is String && hostname.isNotEmpty;
  }

  /// Compares two rules deeply, treating hostname casing and a trailing dot as
  /// equivalent while considering every other value, including unknown keys.
  static bool sameRule(Map a, Map b) => _sameValue(a, b);

  /// Finds the first ingress rule that is unchanged from [rule].
  static int indexOf(List ingress, Map rule) {
    for (var index = 0; index < ingress.length; index++) {
      final candidate = ingress[index];
      if (candidate is Map && sameRule(candidate, rule)) return index;
    }
    return -1;
  }

  /// Replaces [original] at its current position, or inserts [rule] before a
  /// final catch-all rule when creating a new route.
  static List<dynamic> upsert(
    List ingress, {
    Map? original,
    required Map rule,
  }) {
    final updated = List<dynamic>.from(ingress);
    if (original != null) {
      final index = indexOf(updated, original);
      if (index == -1) {
        throw StateError('The ingress rule changed or no longer exists.');
      }
      updated[index] = Map<dynamic, dynamic>.from(rule);
      return updated;
    }

    final insertBeforeCatchAll =
        updated.isNotEmpty && _isCatchAll(updated.last);
    if (insertBeforeCatchAll) {
      updated.insert(updated.length - 1, Map<dynamic, dynamic>.from(rule));
    } else {
      updated.add(Map<dynamic, dynamic>.from(rule));
    }
    return updated;
  }

  /// Removes the one ingress rule that still exactly matches [rule].
  static List<dynamic> remove(List ingress, Map rule) {
    final updated = List<dynamic>.from(ingress);
    final index = indexOf(updated, rule);
    if (index == -1) {
      throw StateError('The ingress rule changed or no longer exists.');
    }
    updated.removeAt(index);
    return updated;
  }

  /// Adds the required default catch-all only when no final catch-all exists.
  static List<dynamic> ensureCatchAll(List ingress) {
    final updated = List<dynamic>.from(ingress);
    if (updated.isEmpty || !_isCatchAll(updated.last)) {
      updated.add({'service': 'http_status:404'});
    }
    return updated;
  }

  /// Keeps every configuration key intact while replacing only `ingress`.
  static Map<String, dynamic> withIngress(Map? existingConfig, List ingress) {
    return {
      if (existingConfig != null) ...Map<String, dynamic>.from(existingConfig),
      'ingress': List<dynamic>.from(ingress),
    };
  }

  static bool _isCatchAll(dynamic rule) {
    return rule is Map && rule['hostname'] == null && rule['path'] == null;
  }

  static bool _sameValue(dynamic a, dynamic b, [String? key]) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) ||
            !_sameValue(entry.value, b[entry.key], entry.key.toString())) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (!_sameValue(a[index], b[index])) return false;
      }
      return true;
    }
    if (key == 'hostname' && a is String && b is String) {
      return TunnelDns.normalize(a) == TunnelDns.normalize(b);
    }
    return a == b;
  }
}
