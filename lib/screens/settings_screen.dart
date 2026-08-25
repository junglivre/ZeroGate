import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/app_language.dart';
import '../core/constants.dart';
import '../data/local_storage.dart';
import '../data/cloudflare_api.dart';
import 'changelog_screen.dart';
import '../l10n/app_localizations.dart';
import '../widgets/protected_secret_field.dart';

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

  final LocalAuthentication _auth = LocalAuthentication();
  bool _canUseDeviceAuth = false;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  String _themeMode = AppThemeController.systemValue;
  String _language = AppLanguageController.systemValue;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDeviceAuth();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
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

  bool get _supportsDeviceAuth {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> _checkDeviceAuth() async {
    if (!_supportsDeviceAuth) return;
    try {
      final available =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (mounted) setState(() => _canUseDeviceAuth = available);
    } catch (e) {
      debugPrint('Error checking local authentication: $e');
    }
  }

  Future<bool> _authorizeTokenReveal() async {
    final passwordController = TextEditingController();
    var obscurePassword = true;
    String? errorText;

    final authorized = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> verifyPassword() async {
            final valid = await LocalStorage.verifyAppPassword(
              passwordController.text,
            );
            if (!dialogContext.mounted) return;
            if (valid) {
              Navigator.of(dialogContext).pop(true);
            } else {
              setDialogState(() {
                errorText = context.l10n.text('passwordIncorrect');
              });
            }
          }

          Future<void> authenticateDevice() async {
            try {
              final valid = await _auth.authenticate(
                localizedReason:
                    context.l10n.text('tokenRevealBiometricReason'),
                options: const AuthenticationOptions(
                  stickyAuth: true,
                  biometricOnly: false,
                ),
              );
              if (valid && dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (e) {
              debugPrint('Error authorizing token reveal: $e');
              if (dialogContext.mounted) {
                setDialogState(() {
                  errorText = context.l10n.text('localAuthFailed');
                });
              }
            }
          }

          return AlertDialog(
            title: Text(context.l10n.text('authorizeTokenReveal')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.text('tokenRevealPrompt')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    autofocus: !_canUseDeviceAuth,
                    obscureText: obscurePassword,
                    onSubmitted: (_) => verifyPassword(),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('password'),
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  if (_canUseDeviceAuth) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authenticateDevice,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          context.l10n.text('authorizeWithBiometrics'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.text('cancel')),
              ),
              ElevatedButton(
                onPressed: verifyPassword,
                child: Text(context.l10n.text('viewToken')),
              ),
            ],
          );
        },
      ),
    );

    passwordController.dispose();
    return authorized ?? false;
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
          content: Text(context.l10n.text('connectionSuccess',
              values: {'count': '${accounts.length}'})),
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
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
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
                        Icon(Icons.language,
                            size: 20, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('jung.moe',
                            style: TextStyle(color: AppColors.primary)),
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
                        Text('GitHub',
                            style: TextStyle(color: AppColors.primary)),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(context.l10n.text('apiTokenPermissionsHint'),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ProtectedSecretField(
                  controller: _tokenController,
                  authorizeReveal: _authorizeTokenReveal,
                  revealTooltip: context.l10n.text('viewToken'),
                  hideTooltip: context.l10n.text('hideToken'),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: Text(context.l10n.text('updatePassword'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(context.l10n.text('about'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ChangelogScreen()),
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
