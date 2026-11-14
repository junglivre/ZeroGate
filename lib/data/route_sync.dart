import 'tunnel_config.dart';
import 'tunnel_dns.dart';

typedef LoadTunnelConfig = Future<Map<String, dynamic>?> Function();
typedef SaveTunnelConfig = Future<void> Function(Map<String, dynamic> config);
typedef ListDnsRecords = Future<List<dynamic>> Function(
  String zoneId, {
  Map<String, String> filters,
});
typedef WriteDnsRecord = Future<dynamic> Function(
  String zoneId,
  Map<String, dynamic> data,
);
typedef UpdateDnsRecord = Future<dynamic> Function(
  String zoneId,
  String recordId,
  Map<String, dynamic> data,
);
typedef DeleteDnsRecord = Future<void> Function(String zoneId, String recordId);
typedef ConfirmDnsConflict = Future<bool> Function(Map<String, dynamic> record);
typedef ConfirmNoDns = Future<bool> Function(
  String hostname,
  String target, {
  required bool unknown,
});
typedef ReportDnsBlocked = Future<bool> Function(
  List<Map<String, dynamic>> records,
);

/// DNS information already loaded by the tunnel detail screen.
class DnsContext {
  const DnsContext({
    required this.zones,
    required this.tunnelId,
    required this.available,
  });

  final List<Map<String, dynamic>> zones;
  final String tunnelId;
  final bool available;
}

/// Result of a route operation. A result with [ingress] has saved a tunnel
/// configuration and callers should use that exact list to refresh the UI.
sealed class RouteSyncResult {
  const RouteSyncResult(this.ingress);

  final List<dynamic>? ingress;
}

final class RouteSaved extends RouteSyncResult {
  const RouteSaved(super.ingress);
}

final class RouteSavedDnsFailed extends RouteSyncResult {
  const RouteSavedDnsFailed(super.ingress, this.error);

  final Object error;
}

final class RouteCancelled extends RouteSyncResult {
  const RouteCancelled() : super(null);
}

final class RouteChangedElsewhere extends RouteSyncResult {
  const RouteChangedElsewhere() : super(null);
}

final class RouteSaveFailed extends RouteSyncResult {
  const RouteSaveFailed(this.error) : super(null);

  final Object error;
}

/// Signals that a DNS record changed after the conflict prompt was shown.
class DnsChangedException implements Exception {
  const DnsChangedException();
}

/// Signals that a persisted route could not have its previous DNS record
/// removed. The route remains saved and the record can be removed as an orphan.
class DnsDeleteException implements Exception {
  const DnsDeleteException(this.hostname, this.error);

  final String hostname;
  final Object error;
}

class _PreparedDns {
  const _PreparedDns({
    required this.hostname,
    this.zoneId,
    this.plan,
  });

  final String hostname;
  final String? zoneId;
  final DnsPlan? plan;
}

/// Coordinates fresh ingress configuration saves with the matching DNS CNAME.
///
/// It deliberately has no Flutter or HTTP dependency: the screen supplies the
/// API calls and the confirmation dialogs as callbacks.
class RouteSync {
  RouteSync({
    required LoadTunnelConfig loadConfig,
    required SaveTunnelConfig saveConfig,
    required ListDnsRecords listRecords,
    required WriteDnsRecord createRecord,
    required UpdateDnsRecord updateRecord,
    required DeleteDnsRecord deleteRecord,
    required ConfirmDnsConflict confirmConflict,
    required ConfirmNoDns confirmNoDns,
    required ReportDnsBlocked reportBlocked,
  })  : _loadConfig = loadConfig,
        _saveConfig = saveConfig,
        _listRecords = listRecords,
        _createRecord = createRecord,
        _updateRecord = updateRecord,
        _deleteRecord = deleteRecord,
        _confirmConflict = confirmConflict,
        _confirmNoDns = confirmNoDns,
        _reportBlocked = reportBlocked;

  final LoadTunnelConfig _loadConfig;
  final SaveTunnelConfig _saveConfig;
  final ListDnsRecords _listRecords;
  final WriteDnsRecord _createRecord;
  final UpdateDnsRecord _updateRecord;
  final DeleteDnsRecord _deleteRecord;
  final ConfirmDnsConflict _confirmConflict;
  final ConfirmNoDns _confirmNoDns;
  final ReportDnsBlocked _reportBlocked;

  Future<RouteSyncResult> create(
    Map<String, dynamic> rule,
    DnsContext context,
  ) async {
    final prepared = await _prepareDns(rule['hostname'], context);
    if (prepared == null) return const RouteCancelled();

    final saved = await _saveRoutes(
      (ingress) => TunnelConfig.upsert(ingress, rule: rule),
    );
    if (saved is! RouteSaved) return saved;

    return _finishDns(prepared, context, saved.ingress);
  }

  Future<RouteSyncResult> edit(
    Map<String, dynamic> original,
    Map<String, dynamic> rule,
    DnsContext context,
  ) async {
    final prepared = await _prepareDns(rule['hostname'], context);
    if (prepared == null) return const RouteCancelled();

    final saved = await _saveRoutes(
      (ingress) => TunnelConfig.upsert(
        ingress,
        original: original,
        rule: rule,
      ),
    );
    if (saved is! RouteSaved) return saved;

    final applied = await _finishDns(prepared, context, saved.ingress);
    if (applied is! RouteSaved) return applied;

    final originalHostname = original['hostname'];
    final newHostname = rule['hostname'];
    if (originalHostname is String &&
        newHostname is String &&
        TunnelDns.normalize(originalHostname) !=
            TunnelDns.normalize(newHostname)) {
      try {
        await _removeDnsIfOwned(originalHostname, saved.ingress!, context);
      } catch (error) {
        return RouteSavedDnsFailed(
          saved.ingress,
          DnsDeleteException(originalHostname, error),
        );
      }
    }
    return applied;
  }

  Future<RouteSyncResult> delete(
    Map<String, dynamic> rule,
    DnsContext context,
  ) async {
    final saved = await _saveRoutes(
      (ingress) => TunnelConfig.remove(ingress, rule),
    );
    if (saved is! RouteSaved) return saved;

    final hostname = rule['hostname'];
    if (hostname is! String || !context.available) return saved;
    try {
      await _removeDnsIfOwned(hostname, saved.ingress!, context);
      return saved;
    } catch (error) {
      return RouteSavedDnsFailed(
        saved.ingress,
        DnsDeleteException(hostname, error),
      );
    }
  }

  Future<RouteSyncResult> fixDns(
    Map<String, dynamic> rule,
    DnsContext context,
  ) async {
    final prepared = await _prepareDns(rule['hostname'], context);
    if (prepared == null) return const RouteCancelled();
    return _finishDns(prepared, context, null);
  }

  Future<_PreparedDns?> _prepareDns(
    dynamic hostnameValue,
    DnsContext context,
  ) async {
    if (hostnameValue is! String) return null;
    final hostname = TunnelDns.normalize(hostnameValue);
    final target = TunnelDns.target(context.tunnelId);

    if (!context.available) {
      final confirmed = await _confirmNoDns(hostname, target, unknown: true);
      return confirmed ? _PreparedDns(hostname: hostname) : null;
    }

    final zone = TunnelDns.zoneFor(hostname, context.zones);
    final zoneId = zone?['id'];
    if (zoneId is! String) {
      final confirmed = await _confirmNoDns(hostname, target, unknown: false);
      return confirmed ? _PreparedDns(hostname: hostname) : null;
    }

    try {
      final records = await _listRecords(
        zoneId,
        filters: {'name.exact': hostname},
      );
      final maps = records
          .whereType<Map>()
          .map((record) => Map<String, dynamic>.from(record))
          .toList();
      final plan = TunnelDns.planEnsure(hostname, context.tunnelId, maps);
      if (plan case DnsConflictPlan(:final record)) {
        if (!await _confirmConflict(record)) return null;
      } else if (plan case DnsBlockedPlan(:final records)) {
        await _reportBlocked(records);
        return null;
      }
      return _PreparedDns(
        hostname: hostname,
        zoneId: zoneId,
        plan: plan,
      );
    } catch (_) {
      final confirmed = await _confirmNoDns(hostname, target, unknown: true);
      return confirmed ? _PreparedDns(hostname: hostname) : null;
    }
  }

  Future<RouteSyncResult> _finishDns(
    _PreparedDns prepared,
    DnsContext context,
    List<dynamic>? ingress,
  ) async {
    try {
      await _applyDns(prepared, context);
      return RouteSaved(ingress);
    } catch (error) {
      return RouteSavedDnsFailed(ingress, error);
    }
  }

  Future<void> _applyDns(_PreparedDns prepared, DnsContext context) async {
    final plan = prepared.plan;
    final zoneId = prepared.zoneId;
    if (plan == null || zoneId == null || plan is DnsNoopPlan) return;

    final data = TunnelDns.buildRecord(prepared.hostname, context.tunnelId);
    if (plan is DnsCreatePlan) {
      await _createRecord(zoneId, data);
      return;
    }

    final expected = switch (plan) {
      DnsUpdatePlan(:final record) => record,
      DnsConflictPlan(:final record) => record,
      _ => null,
    };
    if (expected == null) return;
    final recordId = expected['id'];
    if (recordId is! String) throw StateError('DNS record has no ID.');

    final current = await _listRecords(
      zoneId,
      filters: {'name.exact': prepared.hostname},
    );
    final matching =
        current.whereType<Map>().map(Map<String, dynamic>.from).where(
              (record) => record['id'] == recordId,
            );
    if (matching.length != 1 || !_sameDnsRecord(matching.single, expected)) {
      throw const DnsChangedException();
    }
    await _updateRecord(zoneId, recordId, data);
  }

  Future<void> _removeDnsIfOwned(
    String hostname,
    List<dynamic> remainingRules,
    DnsContext context,
  ) async {
    if (!context.available) return;
    final normalizedHostname = TunnelDns.normalize(hostname);
    final zone = TunnelDns.zoneFor(normalizedHostname, context.zones);
    final zoneId = zone?['id'];
    if (zoneId is! String) return;

    final records = await _listRecords(
      zoneId,
      filters: {'name.exact': normalizedHostname},
    );
    for (final record in records.whereType<Map>()) {
      final value = Map<String, dynamic>.from(record);
      final recordId = value['id'];
      if (recordId is String &&
          TunnelDns.shouldDelete(
            value,
            context.tunnelId,
            normalizedHostname,
            remainingRules.whereType<Map>().map(Map<String, dynamic>.from),
          )) {
        await _deleteRecord(zoneId, recordId);
      }
    }
  }

  Future<RouteSyncResult> _saveRoutes(
    List<dynamic> Function(List<dynamic> ingress) mutate,
  ) async {
    try {
      final config = await _loadConfig();
      final ingress = config?['ingress'];
      final currentIngress = ingress is List ? ingress : <dynamic>[];
      final updatedIngress =
          TunnelConfig.ensureCatchAll(mutate(currentIngress));
      await _saveConfig(TunnelConfig.withIngress(config, updatedIngress));
      return RouteSaved(updatedIngress);
    } on StateError {
      return const RouteChangedElsewhere();
    } catch (error) {
      return RouteSaveFailed(error);
    }
  }

  bool _sameDnsRecord(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['id'] == b['id'] &&
      a['type'] == b['type'] &&
      a['content'] == b['content'] &&
      a['proxied'] == b['proxied'];
}
