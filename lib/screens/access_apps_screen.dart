import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/access_api.dart';
import 'access_app_detail_screen.dart';
import '../l10n/app_localizations.dart';

class AccessAppsScreen extends StatefulWidget {
  final String accountId;

  const AccessAppsScreen({super.key, required this.accountId});

  @override
  State<AccessAppsScreen> createState() => _AccessAppsScreenState();
}

class _AccessAppsScreenState extends State<AccessAppsScreen>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _apps = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int _loadId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final loadId = ++_loadId;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var first = true;
      await for (final app in AccessApi.streamAccessApps(widget.accountId)) {
        if (!mounted || loadId != _loadId) return;
        setState(() {
          if (first) {
            _apps = [];
            first = false;
          }
          _apps.add(app);
        });
      }
      if (!mounted || loadId != _loadId) return;
      setState(() {
        if (first) _apps = [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error =
            context.l10n.text('accessAppsLoadError', values: {'error': '$e'});
        _isLoading = false;
      });
    }
  }

  void _showCreateAppDialog() {
    final nameController = TextEditingController();
    final domainController = TextEditingController();
    final sessionController = TextEditingController(text: '24h');

    Future<void> onCreate() async {
      final name = nameController.text.trim();
      final domain = domainController.text.trim();
      if (name.isEmpty || domain.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.text('nameAndDomainRequired')),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      try {
        await AccessApi.createAccessApp(widget.accountId, {
          'name': name,
          'type': 'self_hosted',
          'domain': domain,
          'session_duration': sessionController.text.trim().isEmpty
              ? '24h'
              : sessionController.text.trim(),
        });
        if (mounted) Navigator.pop(context);
        _loadApps();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.text('createError', values: {'error': '$e'})),
          backgroundColor: AppColors.error,
        ));
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('newAccessApp')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.text('name')),
            ),
            TextField(
              controller: domainController,
              decoration: InputDecoration(
                labelText: context.l10n.text('domain'),
                hintText: 'app.exemplo.com',
              ),
            ),
            TextField(
              controller: sessionController,
              onSubmitted: (_) => onCreate(),
              decoration: InputDecoration(
                labelText: context.l10n.text('sessionDuration'),
                hintText: context.l10n.text('sessionDurationHint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.text('cancel')),
          ),
          ElevatedButton(
            onPressed: onCreate,
            child: Text(context.l10n.text('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.l10n.text('searchAccessApp'),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                tooltip: context.l10n.text('newAccessApp'),
                onPressed: _showCreateAppDialog,
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    final filtered = _apps.where((app) {
      final name = (app['name'] ?? '').toString().toLowerCase();
      final domain = (app['domain'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || domain.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadApps,
      child: filtered.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Center(
                    child: Text(
                      _apps.isEmpty
                          ? context.l10n.text('noAccessApps')
                          : context.l10n.text('noAccessAppsSearch'),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final app = filtered[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(app['name'] ?? app['id'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(app['domain'] ?? ''),
                    trailing: Chip(label: Text(app['type'] ?? '')),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccessAppDetailScreen(
                            accountId: widget.accountId,
                            appId: app['id'],
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
