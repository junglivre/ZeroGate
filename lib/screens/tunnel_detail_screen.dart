import 'package:flutter/material.dart';
import '../core/constants.dart';
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
  Set<String> _sharedNetworks = {};
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final connections =
          await TunnelsApi.getTunnelConnections(widget.accountId, widget.tunnelId);
      final ingress =
          await TunnelsApi.getIngressRules(widget.accountId, widget.tunnelId);
      final allPrivateRoutes =
          await TunnelsApi.listPrivateNetworkRoutes(widget.accountId);
      if (!mounted) return;
      // A network (CIDR) is "shared" when more than one distinct tunnel
      // routes it — e.g. the same private range reachable through two
      // tunnels in different virtual networks.
      final tunnelsByNetwork = <String, Set<String>>{};
      for (final route in allPrivateRoutes) {
        final network = route['network']?.toString();
        final tunnelId = route['tunnel_id']?.toString();
        if (network == null || tunnelId == null) continue;
        tunnelsByNetwork.putIfAbsent(network, () => {}).add(tunnelId);
      }
      setState(() {
        _connections = connections;
        _routes = ingress.where((rule) => rule['hostname'] != null).toList();
        _privateRoutes = allPrivateRoutes
            .where((route) => route['tunnel_id'] == widget.tunnelId)
            .toList();
        _sharedNetworks = {
          for (final entry in tunnelsByNetwork.entries)
            if (entry.value.length > 1) entry.key,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.text('routesLoadError', values: {'error': '$e'});
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRoutes(List<Map<String, dynamic>> newRoutes) async {
    setState(() => _isSaving = true);
    try {
      await TunnelsApi.saveIngressRules(
          widget.accountId, widget.tunnelId, newRoutes);
      if (!mounted) return;
      setState(() {
        _routes = newRoutes;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(context.l10n.text('routeSaveError', values: {'error': '$e'})),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _confirmDeleteRoute(int index) async {
    final route = _routes[index];
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
    if (confirm == true) {
      final newRoutes = List<Map<String, dynamic>>.from(
          _routes.map((r) => Map<String, dynamic>.from(r)));
      newRoutes.removeAt(index);
      _saveRoutes(newRoutes);
    }
  }

  Future<void> _openRouteEditor([int? index]) async {
    final existing = index != null
        ? Map<String, dynamic>.from(_routes[index] as Map)
        : null;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RouteEditorScreen(route: existing),
      ),
    );
    if (result == null) return;

    final newRoutes = List<Map<String, dynamic>>.from(
        _routes.map((r) => Map<String, dynamic>.from(r)));
    if (index != null) {
      newRoutes[index] = result;
    } else {
      newRoutes.add(result);
    }

    await _saveRoutes(newRoutes);
  }

  String _formatOpenedAt(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return parsed.toLocal().toString();
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
      children: allConnections.map((conn) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.hub, color: AppColors.success),
            title: Text(conn['colo_name'] ?? '?'),
            subtitle: Text([
              if (conn['origin_ip'] != null) conn['origin_ip'],
              _formatOpenedAt(conn['opened_at']),
            ].where((part) => part != null && part.toString().isNotEmpty).join(' · ')),
          ),
        );
      }).toList(),
    );
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
        final route = entry.value;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(route['hostname'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(route['service'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _openRouteEditor(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _confirmDeleteRoute(index),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

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
            title: Text(network, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              if (virtualNetworkName != null && virtualNetworkName.isNotEmpty)
                virtualNetworkName,
              if (comment != null && comment.isNotEmpty) comment,
            ].join(' · ')),
            trailing: isShared
                ? Chip(
                    label: Text(context.l10n.text('sharedRoute')),
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(
                        color: AppColors.error, fontSize: 12),
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
                      padding: const EdgeInsets.all(16.0),
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
                          onPressed: _isSaving ? null : () => _openRouteEditor(),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.text('addRoute')),
                        ),
                      ],
                    ),
                  ),
                  _buildRoutesSection(),
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
