import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerogate/l10n/app_localizations.dart';
import 'package:zerogate/widgets/protected_secret_field.dart';
import 'package:zerogate/widgets/token_setup_guide.dart';

void main() {
  testWidgets('secret stays hidden until authorization succeeds',
      (tester) async {
    final controller = TextEditingController(text: 'secret-token');
    var authorized = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtectedSecretField(
            controller: controller,
            authorizeReveal: () async => authorized,
            revealTooltip: 'View token',
            hideTooltip: 'Hide token',
          ),
        ),
      ),
    );

    EditableText editableText() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(editableText().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(editableText().obscureText, isTrue);

    authorized = true;
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(editableText().obscureText, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(editableText().obscureText, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('token guide presents permissions and both next actions',
      (tester) async {
    var openedCloudflare = false;
    var openedSettings = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TokenSetupGuide(
            openCloudflare: () => openedCloudflare = true,
            configureToken: () => openedSettings = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configure your Cloudflare token'), findsOneWidget);
    expect(find.textContaining('Cloudflare Tunnel'), findsOneWidget);
    expect(
      find.text(
        'Create a custom token with the following scope and permissions:',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Account Settings'), findsOneWidget);
    expect(find.textContaining('Account Resources'), findsOneWidget);
    expect(find.text('Scope'), findsOneWidget);
    expect(find.text('Permission'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
    expect(find.text('Account'), findsNWidgets(3));
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Read, Edit'), findsNWidgets(2));
    expect(find.text('Read'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Configure token'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Cloudflare API Tokens'));
    await tester.tap(find.text('Configure token'));

    expect(openedCloudflare, isTrue);
    expect(openedSettings, isTrue);
  });
}
