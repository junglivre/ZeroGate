import 'package:flutter/material.dart';
import '../data/local_storage.dart';
import 'tunnels_screen.dart';
import 'access_apps_screen.dart';
import 'settings_screen.dart';
import 'accounts_screen.dart';
import 'login_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final String accountId;
  final String accountName;

  const HomeScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountsScreen()),
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
        title: Text(widget.accountName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.text('tunnels'), icon: const Icon(Icons.dns)),
            Tab(
              text: context.l10n.text('accessApps'),
              icon: const Icon(Icons.shield_outlined),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.text('switchAccount'),
            icon: const Icon(Icons.swap_horiz),
            onPressed: _switchAccount,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TunnelsScreen(accountId: widget.accountId),
          AccessAppsScreen(accountId: widget.accountId),
        ],
      ),
    );
  }
}
