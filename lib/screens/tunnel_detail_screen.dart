import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/dns_api.dart';
import '../data/route_sync.dart';
import '../data/tunnel_config.dart';
import '../data/tunnel_dns.dart';
import '../data/tunnels_api.dart';
import '../l10n/app_localizations.dart';
import 'route_editor_screen.dart';

class TunnelDetailScreen extends StatefulWidget {
  final String accountId;
  final String tunnelId;
  final String tunnelName;

  const TunnelDetailScreen({
    super.key,
    required this.accountId,
    required this.tunnelId,
    required this.tunnelName,
  });

  @override
  State<TunnelDetailScreen> createState() => _TunnelDetailScreenState();
}

class _TunnelDetailScreenState extends State<TunnelDetailScreen> {
  List<dynamic> _connections = [];
  List<dynamic> _routes = [];
  List<dynamic> _privateRoutes = [];
  List<dynamic> _zones = [];
  Map<String, DnsStatus> _dnsStatus = {};
  List<Map<String, dynamic>> _orphanRecords = [];
  Set<String> _sharedNetworks = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dnsUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> get _routeMaps => _routes
      .whereType<Map>()
      .map((route) => Map<String, dynamic>.from(route))
      .toList();

  List<Map<String, dynamic>> get _zoneMaps => _zones
      .whereType<Map>()
      .map((zone) => Map<String, dynamic>.from(zone))
      .toList();

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final connections = await TunnelsApi.getTunnelConnections(
        widget.accountId,
        widget.tunnelId,
      );
      final config = await TunnelsApi.getTunnelConfig(
        widget.accountId,
        widget.tunnelId,
      );
      final ingress = config?['ingress'];
      final allPrivateRoutes =
          await TunnelsApi.listPrivateNetworkRoutes(widget.accountId);
      if (!mounted) return;

      final tunnelsByNetwork = <String, Set<String>>{};
      for (final route in allPrivateRoutes) {
        final network = route['network']?.toString();
        final tunnelId = route['tunnel_id']?.toString();
        if (network == null || tunnelId == null) continue;
        tunnelsByNetwork.putIfAbsent(network, () => {}).add(tunnelId);
      }
      setState(() {
        _connections = connections;
        _routes = ingress is List
            ? ingress
                .where(
                    (rule) => rule is Map && TunnelConfig.isHostnameRule(rule))
                .map((rule) => Map<String, dynamic>.from(rule as Map))
                .toList()
            : [];
        _privateRoutes = allPrivateRoutes
            .where((route) => route['tunnel_id'] == widget.tunnelId)
            .toList();
        _sharedNetworks = {
          for (final entry in tunnelsByNetwork.entries)
            if (entry.value.length > 1) entry.key,
        };
        _isLoading = false;
      });
      await _loadDnsStatus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            context.l10n.text('routesLoadError', values: {'error': '$error'});
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDnsStatus() async {
    if (!mounted) return;
    setState(() {
      _dnsUnavailable = false;
      _dnsStatus = {};
      _zones = [];
      _orphanRecords = [];
    });

    final routes = _routeMaps;
    try {
      final zones = await DnsApi.listZones(widget.accountId);
      if (!mounted) return;
      final zoneMaps = zones
          .whereType<Map>()
          .map((zone) => Map<String, dynamic>.from(zone))
          .toList();
      final zoneIds = <String>{
        for (final route in routes)
          if (TunnelDns.zoneFor(
                  route['hostname']?.toString() ?? '', zoneMaps)?['id']
              case final String id)
            id,
      };
      final recordsByZone = <String, List<Map<String, dynamic>>>{};
      final failedZoneIds = <String>{};
      for (final zoneId in zoneIds) {
        try {
          final records = await DnsApi.listRecords(
            zoneId,
            filters: {
              'type': 'CNAME',
              'content.exact': TunnelDns.target(widget.tunnelId),
            },
          );
          recordsByZone[zoneId] = records
              .whereType<Map>()
              .map((record) => Map<String, dynamic>.from(record))
              .toList();
        } catch (_) {
          failedZoneIds.add(zoneId);
        }
      }
      final result = TunnelDns.deriveStatus(
        routes,
        zoneMaps,
        recordsByZone,
        failedZoneIds,
      );
      if (!mounted) return;
      setState(() {
        _zones = zoneMaps;
        _dnsStatus = result.statuses;
        _orphanRecords = result.orphanRecords;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dnsUnavailable = true;
        _dnsStatus = {
          for (final route in routes)
            if (route['hostname'] case final String hostname)
              TunnelDns.normalize(hostname): DnsStatus.unknown,
        };
      });
    }
  }

  DnsContext get _dnsContext => DnsContext(
        zones: _zoneMaps,
        tunnelId: widget.tunnelId,
        available: !_dnsUnavailable,
      );

  RouteSync _routeSync() => RouteSync(
        loadConfig: () => TunnelsApi.getTunnelConfig(
          widget.accountId,
          widget.tunnelId,
        ),
        saveConfig: (config) => TunnelsApi.saveTunnelConfig(
          widget.accountId,
          widget.tunnelId,
          config,
        ),
        listRecords: DnsApi.listRecords,
        createRecord: DnsApi.createRecord,
        updateRecord: DnsApi.updateRecord,
        deleteRecord: DnsApi.deleteRecord,
        confirmConflict: _confirmDnsConflict,
        confirmNoDns: _confirmNoDns,
        reportBlocked: _reportDnsBlocked,
      );

  Future<bool> _confirmDnsConflict(Map<String, dynamic> record) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.text('dnsConflictTitle')),
            content: Text(context.l10n.text('dnsConflictBody', values: {
              'type': '${record['type']}',
              'content': '${record['content']}',
            })),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.text('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.text('dnsReplace')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmNoDns(
    String hostname,
    String target, {
    required bool unknown,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.text('dnsNoZoneTitle')),
            content: Text([
              context.l10n.text(
                unknown ? 'dnsUnknownBody' : 'dnsNoZoneBody',
                values: unknown
                    ? const {}
                    : {'hostname': hostname, 'target': target},
              ),
              if (unknown)
                context.l10n.text(
                  'dnsNoZoneBody',
                  values: {'hostname': hostname, 'target': target},
                ),
            ].join('\n\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.text('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.text('saveWithoutDns')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _reportDnsBlocked(List<Map<String, dynamic>> records) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.text('dnsConflictTitle')),
        content: Text([
          context.l10n.text('dnsBlockedBody'),
          ...records.map((record) => '${record['type']}: ${record['content']}'),
        ].join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.text('cancel')),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _runRouteOperation(
    Future<RouteSyncResult> Function(RouteSync sync, DnsContext context)
        operation,
  ) async {
    setState(() => _isSaving = true);
    final result = await operation(_routeSync(), _dnsContext);
    if (!mounted) return;

    if (result.ingress != null) {
      setState(() {
        _routes = result.ingress!
            .where((rule) => rule is Map && TunnelConfig.isHostnameRule(rule))
            .map((rule) => Map<String, dynamic>.from(rule as Map))
            .toList();
      });
    }
    switch (result) {
      case RouteSaveFailed(:final error):
        _showError('routeSaveError', {'error': '$error'});
      case RouteSavedDnsFailed(:final error):
        if (error is DnsChangedException) {
          _showError('dnsChangedRetry');
        } else if (error is DnsDeleteException) {
          _showError('dnsDeleteError', {
            'hostname': error.hostname,
            'error': '${error.error}',
          });
        } else {
          _showError('dnsSyncError', {'error': '$error'});
        }
      case RouteChangedElsewhere():
        _showError('routeChangedElsewhere');
      case RouteSaved() || RouteCancelled():
        break;
    }

    if (result is RouteChangedElsewhere) {
      await _loadAll();
    } else {
      await _loadDnsStatus();
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showError(String key, [Map<String, String> values = const {}]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.text(key, values: values)),
      backgroundColor: AppColors.error,
    ));
  }

  Future<void> _confirmDeleteRoute(int index) async {
    final route = Map<String, dynamic>.from(_routes[index] as Map);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.text('deleteRouteConfirmTitle')),
        content: Text(context.l10n.text('deleteRouteConfirm',
            values: {'hostname': '${route['hostname']}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _runRouteOperation((sync, context) => sync.delete(route, context));
    }
  }

  Future<void> _openRouteEditor([int? index]) async {
    final existing =
        index == null ? null : Map<String, dynamic>.from(_routes[index] as Map);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => RouteEditorScreen(route: existing)),
    );
    if (result == null || !mounted) return;
    await _runRouteOperation(
      (sync, context) => existing == null
          ? sync.create(result, context)
          : sync.edit(existing, result, context),
    );
  }

  Future<void> _fixDns(Map<String, dynamic> route) => _runRouteOperation(
        (sync, context) => sync.fixDns(route, context),
      );

  Future<void> _deleteOrphan(Map<String, dynamic> record) async {
    final name = record['name']?.toString() ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.text('deleteRouteConfirmTitle')),
        content: Text(
            context.l10n.text('deleteOrphanConfirm', values: {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    final zoneId = record['zoneId'];
    final recordId = record['id'];
    if (confirm != true ||
        zoneId is! String ||
        recordId is! String ||
        !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await DnsApi.deleteRecord(zoneId, recordId);
      await _loadDnsStatus();
    } catch (error) {
      if (mounted) {
        _showError('dnsDeleteError', {'hostname': name, 'error': '$error'});
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatOpenedAt(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal().toString() ?? value.toString();
  }

  Widget _buildConnectionsSection() {
    final allConnections = <dynamic>[];
    for (final replica in _connections) {
      final conns = replica['conns'];
      if (conns is List) allConnections.addAll(conns);
    }
    if (allConnections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(context.l10n.text('noConnectors'),
            style: const TextStyle(color: AppColors.error)),
      );
    }
    return Column(
      children: allConnections
          .map((conn) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.hub, color: AppColors.success),
                  title: Text(conn['colo_name'] ?? '?'),
                  subtitle: Text([
                    if (conn['origin_ip'] != null) conn['origin_ip'],
                    _formatOpenedAt(conn['opened_at']),
                  ]
                      .where(
                          (part) => part != null && part.toString().isNotEmpty)
                      .join(' · ')),
                ),
              ))
          .toList(),
    );
  }

  Widget _dnsBadge(String hostname) {
    final status =
        _dnsStatus[TunnelDns.normalize(hostname)] ?? DnsStatus.unknown;
    final (IconData icon, Color color, String message) = switch (status) {
      DnsStatus.ok => (
          Icons.public,
          AppColors.success,
          context.l10n.text('dnsOk')
        ),
      DnsStatus.missing => (
          Icons.error_outline,
          AppColors.error,
          context.l10n.text('dnsMissing')
        ),
      DnsStatus.noZone => (
          Icons.public_off,
          Colors.grey,
          context.l10n.text('dnsNoZone')
        ),
      DnsStatus.unknown => (
          Icons.help_outline,
          Colors.orange,
          context.l10n.text('dnsUnknown')
        ),
    };
    return Tooltip(message: message, child: Icon(icon, color: color));
  }

  Widget _buildRoutesSection() {
    if (_routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(context.l10n.text('noRoutes')),
      );
    }
    return Column(
      children: _routes.asMap().entries.map((entry) {
        final index = entry.key;
        final route = Map<String, dynamic>.from(entry.value as Map);
        final hostname = route['hostname']?.toString() ?? '';
        final status = _dnsStatus[TunnelDns.normalize(hostname)];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: _dnsBadge(hostname),
            title: Text(hostname,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(route['service']?.toString() ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == DnsStatus.missing)
                  TextButton(
                    onPressed: _isSaving ? null : () => _fixDns(route),
                    child: Text(context.l10n.text('dnsFix')),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _isSaving ? null : () => _openRouteEditor(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed:
                      _isSaving ? null : () => _confirmDeleteRoute(index),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrphansSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(context.l10n.text('dnsOrphans'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._orphanRecords.map((record) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.public_off, color: AppColors.error),
                  title: Text(record['name']?.toString() ?? ''),
                  subtitle: Text(record['content']?.toString() ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: _isSaving ? null : () => _deleteOrphan(record),
                  ),
                ),
              )),
        ],
      );

  Widget _buildPrivateRoutesSection() {
    if (_privateRoutes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(context.l10n.text('noPrivateRoutes')),
      );
    }
    return Column(
      children: _privateRoutes.map((route) {
        final network = route['network']?.toString() ?? '';
        final virtualNetworkName = route['virtual_network_name']?.toString();
        final comment = route['comment']?.toString();
        final isShared = _sharedNetworks.contains(network);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.lan, color: AppColors.primary),
            title: Text(network,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              if (virtualNetworkName != null && virtualNetworkName.isNotEmpty)
                virtualNetworkName,
              if (comment != null && comment.isNotEmpty) comment,
            ].join(' · ')),
            trailing: isShared
                ? Chip(
                    label: Text(context.l10n.text('sharedRoute')),
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    labelStyle:
                        const TextStyle(color: AppColors.error, fontSize: 12),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tunnelName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(context.l10n.text('connectors'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildConnectionsSection(),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l10n.text('routes'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed:
                              _isSaving ? null : () => _openRouteEditor(),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.text('addRoute')),
                        ),
                      ],
                    ),
                  ),
                  if (_dnsUnavailable)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber,
                              color: Colors.orange),
                          title:
                              Text(context.l10n.text('dnsUnavailableBanner')),
                          trailing: TextButton(
                            onPressed: _isSaving ? null : _loadDnsStatus,
                            child: Text(context.l10n.text('retry')),
                          ),
                        ),
                      ),
                    ),
                  _buildRoutesSection(),
                  if (_orphanRecords.isNotEmpty) _buildOrphansSection(),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(context.l10n.text('privateRoutes'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildPrivateRoutesSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
