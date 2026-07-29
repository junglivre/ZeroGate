import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/access_api.dart';
import '../l10n/app_localizations.dart';

const _knownSelectors = ['email', 'email_domain', 'everyone', 'ip'];
const _ruleGroups = ['include', 'exclude', 'require'];

class _EditableRule {
  String selector;
  final TextEditingController controller;
  _EditableRule(this.selector, String initialValue)
      : controller = TextEditingController(text: initialValue);
}

bool _isKnownRule(dynamic rule) {
  return rule is Map &&
      rule.length == 1 &&
      _knownSelectors.contains(rule.keys.first);
}

_EditableRule _ruleToEditable(Map rule) {
  final selector = rule.keys.first as String;
  String value = '';
  switch (selector) {
    case 'email':
      value = rule['email']?['email']?.toString() ?? '';
      break;
    case 'email_domain':
      value = rule['email_domain']?['domain']?.toString() ?? '';
      break;
    case 'ip':
      value = rule['ip']?['ip']?.toString() ?? '';
      break;
  }
  return _EditableRule(selector, value);
}

Map<String, dynamic> _editableToRule(_EditableRule rule) {
  final value = rule.controller.text.trim();
  switch (rule.selector) {
    case 'email':
      return {
        'email': {'email': value}
      };
    case 'email_domain':
      return {
        'email_domain': {'domain': value}
      };
    case 'ip':
      return {
        'ip': {'ip': value}
      };
    case 'everyone':
    default:
      return {'everyone': {}};
  }
}

/// Edits (or creates) an Access policy attached to a self-hosted app.
///
/// Only a curated set of common selectors is editable here: email,
/// email domain, everyone and IP range. Any other selector already present
/// on the policy (device posture, IdP groups, geo, service tokens, etc.) is
/// preserved untouched on save instead of being silently dropped.
class AccessPolicyEditorScreen extends StatefulWidget {
  final String accountId;
  final String appId;
  final Map<String, dynamic>? policy;

  const AccessPolicyEditorScreen({
    super.key,
    required this.accountId,
    required this.appId,
    this.policy,
  });

  @override
  State<AccessPolicyEditorScreen> createState() =>
      _AccessPolicyEditorScreenState();
}

class _AccessPolicyEditorScreenState extends State<AccessPolicyEditorScreen> {
  final _nameController = TextEditingController();
  String _decision = 'allow';
  bool _isSaving = false;

  final Map<String, List<_EditableRule>> _editable = {
    for (final group in _ruleGroups) group: <_EditableRule>[],
  };
  final Map<String, List<dynamic>> _passthrough = {
    for (final group in _ruleGroups) group: <dynamic>[],
  };

  bool get _isEditing => widget.policy != null;

  @override
  void initState() {
    super.initState();
    final policy = widget.policy;
    if (policy != null) {
      _nameController.text = policy['name'] ?? '';
      _decision = policy['decision'] ?? 'allow';
      for (final group in _ruleGroups) {
        final rules = policy[group];
        if (rules is! List) continue;
        for (final rule in rules) {
          if (_isKnownRule(rule)) {
            _editable[group]!.add(_ruleToEditable(rule as Map));
          } else {
            _passthrough[group]!.add(rule);
          }
        }
      }
    } else {
      _editable['include']!.add(_EditableRule('everyone', ''));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final group in _ruleGroups) {
      for (final rule in _editable[group]!) {
        rule.controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.text('policyNameRequired')),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final includeTotal =
        _editable['include']!.length + _passthrough['include']!.length;
    if (includeTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.text('policyIncludeRequired')),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    for (final group in _ruleGroups) {
      for (final rule in _editable[group]!) {
        if (rule.selector != 'everyone' && rule.controller.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.text('ruleValueRequired')),
            backgroundColor: AppColors.error,
          ));
          return;
        }
      }
    }

    final body = {
      'name': name,
      'decision': _decision,
      for (final group in _ruleGroups)
        group: [
          ..._passthrough[group]!,
          ..._editable[group]!.map(_editableToRule),
        ],
    };

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await AccessApi.updateAccessPolicy(
            widget.accountId, widget.appId, widget.policy!['id'], body);
      } else {
        await AccessApi.createAccessPolicy(
            widget.accountId, widget.appId, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(context.l10n.text('policySaveError', values: {'error': '$e'})),
        backgroundColor: AppColors.error,
      ));
    }
  }

  String _selectorLabel(String selector) {
    switch (selector) {
      case 'email':
        return context.l10n.text('selectorEmail');
      case 'email_domain':
        return context.l10n.text('selectorEmailDomain');
      case 'ip':
        return context.l10n.text('selectorIp');
      case 'everyone':
      default:
        return context.l10n.text('selectorEveryone');
    }
  }

  String _decisionLabel(String decision) {
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

  String _groupLabel(String group) {
    switch (group) {
      case 'exclude':
        return context.l10n.text('exclude');
      case 'require':
        return context.l10n.text('require');
      case 'include':
      default:
        return context.l10n.text('include');
    }
  }

  Widget _buildRuleGroup(String group) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_groupLabel(group),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._editable[group]!.asMap().entries.map((entry) {
            final index = entry.key;
            final rule = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: rule.selector,
                    items: _knownSelectors
                        .map((selector) => DropdownMenuItem(
                              value: selector,
                              child: Text(_selectorLabel(selector)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => rule.selector = value);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: rule.controller,
                      enabled: rule.selector != 'everyone',
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.error),
                    onPressed: () {
                      setState(() => _editable[group]!.removeAt(index));
                    },
                  ),
                ],
              ),
            );
          }),
          if (_passthrough[group]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.l10n.text('unsupportedRule',
                    values: {'count': '${_passthrough[group]!.length}'}),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() => _editable[group]!.add(_EditableRule('email', '')));
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.text('addRule')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? context.l10n.text('editPolicy')
            : context.l10n.text('newPolicy')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: context.l10n.text('policyName')),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _decision,
            decoration: InputDecoration(labelText: context.l10n.text('decision')),
            items: ['allow', 'deny', 'bypass', 'non_identity']
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(_decisionLabel(value)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _decision = value);
            },
          ),
          const Divider(height: 32),
          ..._ruleGroups.map(_buildRuleGroup),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.l10n.text('save'),
                      style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
