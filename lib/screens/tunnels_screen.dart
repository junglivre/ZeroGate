import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/tunnels_api.dart';
import 'tunnel_detail_screen.dart';
import '../l10n/app_localizations.dart';

class TunnelsScreen extends StatefulWidget {
  final String accountId;

  const TunnelsScreen({super.key, required this.accountId});

  @override
  State<TunnelsScreen> createState() => _TunnelsScreenState();
}

class _TunnelsScreenState extends State<TunnelsScreen>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _tunnels = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int _loadId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTunnels();
  }

  Future<void> _loadTunnels() async {
    final loadId = ++_loadId;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var first = true;
      await for (final tunnel in TunnelsApi.streamTunnels(widget.accountId)) {
        if (!mounted || loadId != _loadId) return;
        setState(() {
          if (first) {
            _tunnels = [];
            first = false;
          }
          _tunnels.add(tunnel);
        });
      }
      if (!mounted || loadId != _loadId) return;
      setState(() {
        if (first) _tunnels = [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error = context.l10n.text('tunnelsLoadError', values: {'error': '$e'});
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'healthy':
        return AppColors.success;
      case 'degraded':
        return Colors.orange;
      case 'down':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'healthy':
        return Icons.check_circle;
      case 'degraded':
        return Icons.warning;
      case 'down':
        return Icons.error;
      default:
        return Icons.circle_outlined;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'healthy':
        return context.l10n.text('tunnelStatusHealthy');
      case 'degraded':
        return context.l10n.text('tunnelStatusDegraded');
      case 'down':
        return context.l10n.text('tunnelStatusDown');
      default:
        return context.l10n.text('tunnelStatusInactive');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.l10n.text('searchTunnel'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _tunnels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _tunnels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    final filtered = _tunnels.where((tunnel) {
      final name = (tunnel['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTunnels,
      child: filtered.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Center(
                    child: Text(
                      _tunnels.isEmpty
                          ? context.l10n.text('noTunnels')
                          : context.l10n.text('noTunnelsSearch'),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final tunnel = filtered[index];
                final status = tunnel['status']?.toString();
                final connections = tunnel['connections'];
                final connectionCount =
                    connections is List ? connections.length : 0;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(_statusIcon(status),
                        color: _statusColor(status)),
                    title: Text(tunnel['name'] ?? tunnel['id'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${_statusLabel(status)} · ${context.l10n.text('connectorsCount', values: {
                            'count': '$connectionCount',
                          })}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TunnelDetailScreen(
                            accountId: widget.accountId,
                            tunnelId: tunnel['id'],
                            tunnelName: tunnel['name'] ?? tunnel['id'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
