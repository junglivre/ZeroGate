import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'core/app_language.dart';
import 'data/local_storage.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/password_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.logout();
  final savedThemeMode = await LocalStorage.getThemeMode();
  AppThemeController.themeMode.value =
      AppThemeController.fromStorageValue(savedThemeMode);
  final savedLanguage = await LocalStorage.getLanguage();
  AppLanguageController.locale.value =
      AppLanguageController.fromStorageValue(savedLanguage);
  final hasPassword = await LocalStorage.hasAppPassword();
  runApp(CloudflareZeroTrustApp(hasPassword: hasPassword, isAuth: false));
}

class CloudflareZeroTrustApp extends StatelessWidget {
  final bool hasPassword;
  final bool isAuth;

  const CloudflareZeroTrustApp({
    super.key,
    required this.hasPassword,
    required this.isAuth,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale?>(
        valueListenable: AppLanguageController.locale,
        builder: (context, locale, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ZeroGate',
            locale: locale,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale != null) {
                for (final supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode ==
                      deviceLocale.languageCode) {
                    return supportedLocale;
                  }
                }
              }
              return const Locale('en');
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppThemeController.lightTheme,
            darkTheme: AppThemeController.darkTheme,
            themeMode: themeMode,
            home: !hasPassword
                ? const PasswordSetupScreen()
                : isAuth
                    ? const AccountsScreen()
                    : const LoginScreen(),
          );
        },
      ),
    );
  }
}
