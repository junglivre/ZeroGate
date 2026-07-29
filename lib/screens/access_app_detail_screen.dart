import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/access_api.dart';
import 'access_policy_editor_screen.dart';
import '../l10n/app_localizations.dart';

class AccessAppDetailScreen extends StatefulWidget {
  final String accountId;
  final String appId;

  const AccessAppDetailScreen({
    super.key,
    required this.accountId,
    required this.appId,
  });

  @override
  State<AccessAppDetailScreen> createState() => _AccessAppDetailScreenState();
}

class _AccessAppDetailScreenState extends State<AccessAppDetailScreen> {
  Map<String, dynamic>? _app;
  List<dynamic> _policies = [];
  bool _isLoading = true;
  bool _isSavingApp = false;
  String? _error;

  final _nameController = TextEditingController();
  final _domainController = TextEditingController();
  final _sessionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final app = await AccessApi.getAccessApp(widget.accountId, widget.appId);
      final policies =
          await AccessApi.listAccessPolicies(widget.accountId, widget.appId);
      if (!mounted) return;
      setState(() {
        _app = app;
        _policies = policies;
        _nameController.text = app['name'] ?? '';
        _domainController.text = app['domain'] ?? '';
        _sessionController.text = app['session_duration'] ?? '24h';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            context.l10n.text('accessAppsLoadError', values: {'error': '$e'});
        _isLoading = false;
      });
    }
  }

  Future<void> _saveApp() async {
    if (_app == null) return;
    setState(() => _isSavingApp = true);
    final updated = Map<String, dynamic>.from(_app!);
    updated['name'] = _nameController.text.trim();
    updated['domain'] = _domainController.text.trim();
    updated['session_duration'] = _sessionController.text.trim().isEmpty
        ? '24h'
        : _sessionController.text.trim();

    try {
      await AccessApi.updateAccessApp(widget.accountId, widget.appId, updated);
      if (!mounted) return;
      setState(() {
        _app = updated;
        _isSavingApp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.text('saved')),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingApp = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(context.l10n.text('updateError', values: {'error': '$e'})),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _confirmDeleteApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.text('deleteAppConfirmTitle')),
        content: Text(context.l10n.text('deleteAppConfirm',
            values: {'name': _nameController.text})),
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
      try {
        await AccessApi.deleteAccessApp(widget.accountId, widget.appId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.l10n.text('deleteError', values: {'error': '$e'})),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _confirmDeletePolicy(Map policy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.text('deletePolicyConfirmTitle')),
        content: Text(context.l10n
            .text('deletePolicyConfirm', values: {'name': '${policy['name']}'})),
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
      try {
        await AccessApi.deleteAccessPolicy(
            widget.accountId, widget.appId, policy['id']);
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.l10n.text('deleteError', values: {'error': '$e'})),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _openPolicyEditor([Map<String, dynamic>? policy]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccessPolicyEditorScreen(
          accountId: widget.accountId,
          appId: widget.appId,
          policy: policy,
        ),
      ),
    );
    if (saved == true) _loadAll();
  }

  String _decisionLabel(String? decision) {
    switch (decision) {
      case 'deny':
        return context.l10n.text('decisionDeny');
      case 'bypass':
        return context.l10n.text('decisionBypass');
      case 'non_identity':
        return context.l10n.text('decisionNonIdentity');
      case 'allow':
      default:
        return context.l10n.text('decisionAllow');
    }
  }

  Color _decisionColor(String? decision) {
    switch (decision) {
      case 'deny':
        return AppColors.error;
      case 'bypass':
        return Colors.grey;
      case 'non_identity':
        return Colors.blueGrey;
      case 'allow':
      default:
        return AppColors.success;
    }
  }

  Widget _buildPoliciesSection() {
    if (_policies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(context.l10n.text('noPolicies')),
      );
    }

    return Column(
      children: _policies.map((policy) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(policy['name'] ?? ''),
            subtitle: Text(_decisionLabel(policy['decision']),
                style: TextStyle(color: _decisionColor(policy['decision']))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _openPolicyEditor(Map<String, dynamic>.from(policy)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _confirmDeletePolicy(policy),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_app != null ? (_app!['name'] ?? '') : ''),
        actions: [
          if (_app != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeleteApp,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _app == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration:
                          InputDecoration(labelText: context.l10n.text('name')),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _domainController,
                      decoration: InputDecoration(
                          labelText: context.l10n.text('domain')),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sessionController,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('sessionDuration'),
                        hintText: context.l10n.text('sessionDurationHint'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSavingApp ? null : _saveApp,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: Text(context.l10n.text('save'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l10n.text('policies'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => _openPolicyEditor(),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.text('newPolicy')),
                        ),
                      ],
                    ),
                    _buildPoliciesSection(),
                  ],
                ),
    );
  }
}
