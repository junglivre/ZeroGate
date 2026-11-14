/// DNS state for a tunnel route.
enum DnsStatus { ok, missing, noZone, unknown }

/// Result of checking the DNS records at one hostname.
sealed class DnsPlan {
  const DnsPlan();
}

/// A matching, proxied record already exists.
final class DnsNoopPlan extends DnsPlan {
  const DnsNoopPlan();
}

/// No conflicting record exists and a tunnel CNAME can be created.
final class DnsCreatePlan extends DnsPlan {
  const DnsCreatePlan();
}

/// The existing tunnel CNAME needs its proxied setting restored.
final class DnsUpdatePlan extends DnsPlan {
  const DnsUpdatePlan(this.record);

  final Map<String, dynamic> record;
}

/// One record occupies the hostname and needs user confirmation to replace.
final class DnsConflictPlan extends DnsPlan {
  const DnsConflictPlan(this.record);

  final Map<String, dynamic> record;
}

/// More than one conflicting record occupies the hostname.
final class DnsBlockedPlan extends DnsPlan {
  const DnsBlockedPlan(this.records);

  final List<Map<String, dynamic>> records;
}

typedef DnsStatusResult = ({
  Map<String, DnsStatus> statuses,
  List<Map<String, dynamic>> orphanRecords,
});

/// Pure helpers for Cloudflare Tunnel DNS records.
class TunnelDns {
  static String target(String tunnelId) => '$tunnelId.cfargotunnel.com';

  /// Canonicalizes hostnames and DNS record content for comparisons.
  static String normalize(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.endsWith('.')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  /// Finds the most specific zone which contains [hostname].
  static Map<String, dynamic>? zoneFor(
    String hostname,
    Iterable<Map<String, dynamic>> zones,
  ) {
    var host = normalize(hostname);
    if (host.startsWith('*.')) {
      host = host.substring(2);
    }

    Map<String, dynamic>? match;
    var matchLength = -1;
    for (final zone in zones) {
      final name = zone['name'];
      if (name is! String) continue;
      final zoneName = normalize(name);
      if (host == zoneName || host.endsWith('.$zoneName')) {
        if (zoneName.length > matchLength) {
          match = zone;
          matchLength = zoneName.length;
        }
      }
    }
    return match;
  }

  /// Builds the Cloudflare-managed CNAME record for a tunnel hostname.
  static Map<String, dynamic> buildRecord(String hostname, String tunnelId) => {
        'type': 'CNAME',
        'name': normalize(hostname),
        'content': target(tunnelId),
        'proxied': true,
        'ttl': 1,
      };

  static bool pointsToTunnel(Map<String, dynamic> record, String tunnelId) {
    final content = record['content'];
    return record['type'] == 'CNAME' &&
        content is String &&
        normalize(content) == target(tunnelId);
  }

  /// Plans the least invasive action for the records at one hostname.
  static DnsPlan planEnsure(
    String hostname,
    String tunnelId,
    Iterable<Map<String, dynamic>> recordsAtName,
  ) {
    final records = recordsAtName
        .where(
            (record) => const {'A', 'AAAA', 'CNAME'}.contains(record['type']))
        .toList();

    if (records.isEmpty) return const DnsCreatePlan();
    if (records.length > 1) return DnsBlockedPlan(records);

    final record = records.single;
    if (!pointsToTunnel(record, tunnelId)) return DnsConflictPlan(record);
    if (record['proxied'] == true) return const DnsNoopPlan();
    return DnsUpdatePlan(record);
  }

  /// Returns whether [record] is an unshared CNAME owned by this tunnel.
  static bool shouldDelete(
    Map<String, dynamic> record,
    String tunnelId,
    String hostname,
    Iterable<Map<String, dynamic>> remainingRules,
  ) {
    if (!pointsToTunnel(record, tunnelId)) return false;

    final normalizedHostname = normalize(hostname);
    return !remainingRules.any((rule) {
      final ruleHostname = rule['hostname'];
      return ruleHostname is String &&
          normalize(ruleHostname) == normalizedHostname;
    });
  }

  /// Derives per-route DNS state and tunnel CNAMEs without matching routes.
  ///
  /// [recordsByZone] contains the CNAMEs already filtered by the caller for
  /// this tunnel target. A zone in [failedZoneIds] is treated as unreadable.
  static DnsStatusResult deriveStatus(
    Iterable<Map<String, dynamic>> routes,
    Iterable<Map<String, dynamic>> zones,
    Map<String, List<Map<String, dynamic>>> recordsByZone,
    Iterable<String> failedZoneIds,
  ) {
    final routeList = routes.toList();
    final failedZoneIdSet = failedZoneIds.toSet();
    final routeHostnames = <String>{
      for (final route in routeList)
        if (route['hostname'] case final String hostname) normalize(hostname),
    };
    final statuses = <String, DnsStatus>{};
    final orphanRecords = <Map<String, dynamic>>[];

    for (final route in routeList) {
      final hostname = route['hostname'];
      if (hostname is! String) continue;

      final normalizedHostname = normalize(hostname);
      final zone = zoneFor(normalizedHostname, zones);
      final zoneId = zone?['id'];
      if (zone == null || zoneId is! String) {
        statuses[normalizedHostname] = DnsStatus.noZone;
        continue;
      }
      if (failedZoneIdSet.contains(zoneId)) {
        statuses[normalizedHostname] = DnsStatus.unknown;
        continue;
      }

      final records = recordsByZone[zoneId] ?? const [];
      final exists = records.any((record) {
        final name = record['name'];
        return name is String &&
            normalize(name) == normalizedHostname &&
            record['proxied'] == true;
      });
      statuses[normalizedHostname] = exists ? DnsStatus.ok : DnsStatus.missing;
    }

    for (final entry in recordsByZone.entries) {
      if (failedZoneIdSet.contains(entry.key)) continue;
      for (final record in entry.value) {
        final name = record['name'];
        if (name is String && !routeHostnames.contains(normalize(name))) {
          orphanRecords.add({...record, 'zoneId': entry.key});
        }
      }
    }

    return (statuses: statuses, orphanRecords: orphanRecords);
  }
}
