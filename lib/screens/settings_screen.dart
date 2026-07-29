import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/app_language.dart';
import '../core/constants.dart';
import '../data/local_storage.dart';
import '../data/cloudflare_api.dart';
import 'changelog_screen.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureToken = true;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  String _themeMode = AppThemeController.systemValue;
  String _language = AppLanguageController.systemValue;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final token = await LocalStorage.getToken();
    final themeMode = await LocalStorage.getThemeMode();
    final language = await LocalStorage.getLanguage();
    if (!mounted) return;
    if (token != null) {
      _tokenController.text = token;
    }
    setState(() {
      _themeMode = themeMode;
      _language = language;
    });
  }

  Future<void> _saveLanguage(String value) async {
    await LocalStorage.saveLanguage(value);
    AppLanguageController.locale.value =
        AppLanguageController.fromStorageValue(value);
    if (mounted) setState(() => _language = value);
  }

  Future<void> _saveThemeMode(String value) async {
    await LocalStorage.saveThemeMode(value);
    AppThemeController.themeMode.value =
        AppThemeController.fromStorageValue(value);
    if (mounted) {
      setState(() {
        _themeMode = value;
      });
    }
  }

  Future<void> _saveToken() async {
    await LocalStorage.saveToken(_tokenController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.text('tokenSaved')),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _testToken() async {
    await LocalStorage.saveToken(_tokenController.text.trim());
    try {
      final accounts = await CloudflareApi.listAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .text('connectionSuccess', values: {'count': '${accounts.length}'})),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.text('connectionFailed')),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (!await LocalStorage.verifyAppPassword(_currentPassController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.text('passwordIncorrect')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (_newPassController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.text('newPasswordEmpty')),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (_newPassController.text != _confirmPassController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.text('passwordMismatchExclaim')),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    await LocalStorage.saveAppPassword(_newPassController.text.trim());
    _currentPassController.clear();
    _newPassController.clear();
    _confirmPassController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.text('passwordUpdated')),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('unableOpenLink'))),
      );
    }
  }

  Widget _buildAboutMeSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundImage: NetworkImage('https://github.com/junglivre.png'),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.text('madeBy', values: {'name': 'Jung'}),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 6),
              Text(context.l10n.text('aboutTagline'),
                  style: const TextStyle(
                      fontSize: 15, fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              Text(context.l10n.text('aboutDescription'),
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  InkWell(
                    onTap: () => _openLink('https://jung.moe'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language, size: 20, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('jung.moe', style: TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _openLink('https://github.com/junglivre'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.code, size: 20, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('GitHub', style: TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context);
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.text('settings')),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.text('apiToken'),
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(context.l10n.text('apiTokenPermissionsHint'),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureToken
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testToken,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700]),
                        child: Text(context.l10n.text('test'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveToken,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: Text(context.l10n.text('save'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(context.l10n.text('appTheme'),
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(context.l10n.text('themeDescription'),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _themeMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.palette),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AppThemeController.systemValue,
                      child: Text(context.l10n.text('systemTheme')),
                    ),
                    DropdownMenuItem(
                      value: AppThemeController.lightValue,
                      child: Text(context.l10n.text('light')),
                    ),
                    DropdownMenuItem(
                      value: AppThemeController.darkValue,
                      child: Text(context.l10n.text('dark')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _saveThemeMode(value);
                    }
                  },
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(context.l10n.text('language'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(context.l10n.text('languageDescription'),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: AppLanguageController.systemValue,
                        child: Text(context.l10n.text('systemLanguage'))),
                    const DropdownMenuItem(
                        value: 'pt', child: Text('Português')),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveLanguage(value);
                  },
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(context.l10n.text('changePassword'),
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _currentPassController,
                  obscureText: _obscureCurrentPass,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('currentPassword'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrentPass
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPass = !_obscureCurrentPass;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPassController,
                  obscureText: _obscureNewPass,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('newPassword'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPass
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureNewPass = !_obscureNewPass;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassController,
                  obscureText: _obscureConfirmPass,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('confirmNewPassword'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPass
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPass = !_obscureConfirmPass;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _changePassword,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text(context.l10n.text('updatePassword'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(context.l10n.text('about'),
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangelogScreen()),
                      );
                    },
                    icon: const Icon(Icons.history, color: AppColors.primary),
                    label: Text(context.l10n.text('viewChangelog'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildAboutMeSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
