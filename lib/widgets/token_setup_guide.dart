import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../l10n/app_localizations.dart';

class TokenSetupGuide extends StatelessWidget {
  const TokenSetupGuide({
    super.key,
    required this.openCloudflare,
    required this.configureToken,
  });

  final VoidCallback openCloudflare;
  final VoidCallback configureToken;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, color: AppColors.primary, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.text('tokenGuideTitle'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.text('tokenGuideIntro')),
                  const SizedBox(height: 20),
                  _GuideStep(
                    number: 1,
                    text: context.l10n.text('tokenGuideStep1'),
                  ),
                  const _PermissionTableStep(),
                  _GuideStep(
                    number: 3,
                    text: context.l10n.text('tokenGuideStep3'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: openCloudflare,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(context.l10n.text('openCloudflareTokens')),
                      ),
                      ElevatedButton.icon(
                        onPressed: configureToken,
                        icon: const Icon(Icons.settings),
                        label: Text(context.l10n.text('configureToken')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepNumber(number),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PermissionTableStep extends StatelessWidget {
  const _PermissionTableStep();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepNumber(2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.text('tokenGuidePermissionsIntro')),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    border:
                        TableBorder.all(color: Theme.of(context).dividerColor),
                    columnWidths: const {
                      0: FlexColumnWidth(0.8),
                      1: FlexColumnWidth(1.8),
                      2: FlexColumnWidth(0.9),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        children: [
                          _PermissionCell(
                            context.l10n.text('tokenGuideScope'),
                            isHeader: true,
                          ),
                          _PermissionCell(
                            context.l10n.text('tokenGuidePermission'),
                            isHeader: true,
                          ),
                          _PermissionCell(
                            context.l10n.text('tokenGuideLevel'),
                            isHeader: true,
                          ),
                        ],
                      ),
                      _permissionRow(
                        context,
                        scope: 'tokenGuideAccount',
                        permission: 'Cloudflare Tunnel',
                        level: 'tokenGuideReadEdit',
                      ),
                      _permissionRow(
                        context,
                        scope: 'tokenGuideAccount',
                        permission: 'Access: Apps and Policies',
                        level: 'tokenGuideReadEdit',
                      ),
                      _permissionRow(
                        context,
                        scope: 'tokenGuideAccount',
                        permission: 'Account Settings',
                        level: 'tokenGuideRead',
                      ),
                      _permissionRow(
                        context,
                        scope: 'tokenGuideUser',
                        permission: 'Memberships',
                        level: 'tokenGuideRead',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _permissionRow(
    BuildContext context, {
    required String scope,
    required String permission,
    required String level,
  }) {
    return TableRow(
      children: [
        _PermissionCell(context.l10n.text(scope)),
        _PermissionCell(permission),
        _PermissionCell(context.l10n.text(level)),
      ],
    );
  }
}

class _PermissionCell extends StatelessWidget {
  const _PermissionCell(this.text, {this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: Text('$number', style: const TextStyle(fontSize: 12)),
    );
  }
}
