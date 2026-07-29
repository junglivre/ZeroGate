import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../data/cloudflare_api.dart';
import '../data/local_storage.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../l10n/app_localizations.dart';

/// Loads the accounts the configured API Token can see and either lets the
/// user pick one (multiple accounts) or jumps straight into [HomeScreen]
/// when there is only one.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<dynamic> _accounts = [];
  Set<String> _pinnedIds = {};
  bool _isLoading = true;
  String? _error;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  List<dynamic> get _sortedAccounts {
    final pinned = <dynamic>[];
    final rest = <dynamic>[];
    for (final account in _accounts) {
      if (_pinnedIds.contains(account['id'])) {
        pinned.add(account);
      } else {
        rest.add(account);
      }
    }
    return [...pinned, ...rest];
  }

  Future<void> _loadAccounts() async {
    final loadId = ++_loadId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final pinned = await LocalStorage.getPinnedAccountIds();
    final token = await LocalStorage.getToken();
    if (!mounted || loadId != _loadId) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = context.l10n.text('tokenNotConfigured');
      });
      return;
    }

    try {
      final accounts = <dynamic>[];
      var first = true;
      await for (final account in CloudflareApi.streamAccounts()) {
        if (!mounted || loadId != _loadId) return;
        accounts.add(account);
        setState(() {
          if (first) {
            _accounts = [];
            _pinnedIds = pinned;
            first = false;
          }
          _accounts = List<dynamic>.from(accounts);
        });
      }
      if (!mounted || loadId != _loadId) return;

      if (accounts.isEmpty) {
        setState(() {
          _accounts = [];
          _isLoading = false;
          _error = context.l10n.text('noAccounts');
        });
        return;
      }

      if (accounts.length == 1) {
        _selectAccount(accounts.first);
        return;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error = context.l10n.text('accountsLoadError', values: {'error': '$e'});
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePinned(String accountId) async {
    await LocalStorage.togglePinnedAccount(accountId);
    final pinned = await LocalStorage.getPinnedAccountIds();
    if (!mounted) return;
    setState(() => _pinnedIds = pinned);
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.text('copiedToClipboard'))),
    );
  }

  void _showCopyOptions(dynamic account) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(context.l10n.text('copyName')),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyToClipboard(account['name'] ?? account['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: Text(context.l10n.text('copyId')),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyToClipboard(account['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectAccount(dynamic account) async {
    await LocalStorage.saveSelectedAccount(account['id'], account['name']);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          accountId: account['id'],
          accountName: account['name'],
        ),
      ),
    );
  }

  void _logout() async {
    await LocalStorage.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('accounts')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadAccounts();
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              if (_error!.contains('Token'))
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    _loadAccounts();
                  },
                  child: Text(context.l10n.text('configureToken')),
                )
              else
                ElevatedButton(
                  onPressed: _loadAccounts,
                  child: Text(context.l10n.text('retry')),
                ),
            ],
          ),
        ),
      );
    }

    final accounts = _sortedAccounts;
    final pinnedCount =
        accounts.where((a) => _pinnedIds.contains(a['id'])).length;
    final showDivider = pinnedCount > 0 && pinnedCount < accounts.length;

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView.builder(
        itemCount: accounts.length + (showDivider ? 1 : 0),
        itemBuilder: (context, index) {
          if (showDivider && index == pinnedCount) {
            return const Divider(height: 24, indent: 16, endIndent: 16);
          }
          final account = accounts[showDivider && index > pinnedCount
              ? index - 1
              : index];
          final isPinned = _pinnedIds.contains(account['id']);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.corporate_fare),
              title: Text(account['name'] ?? account['id'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(account['id']),
              trailing: IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? AppColors.primary : null,
                ),
                tooltip: context.l10n
                    .text(isPinned ? 'unpinAccount' : 'pinAccount'),
                onPressed: () => _togglePinned(account['id']),
              ),
              onTap: () => _selectAccount(account),
              onLongPress: () => _showCopyOptions(account),
            ),
          );
        },
      ),
    );
  }
}
