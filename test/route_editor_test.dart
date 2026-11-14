import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerogate/l10n/app_localizations.dart';
import 'package:zerogate/screens/route_editor_screen.dart';

void main() {
  testWidgets('preserves unknown rule keys and canonicalizes the hostname',
      (tester) async {
    final result = Completer<Map<String, dynamic>?>();
    final route = {
      'hostname': 'App.Example.com.',
      'service': 'http://localhost:8080',
      'path': '/api',
      'originRequest': {
        'access': {'required': true},
        'noTLSVerify': true,
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result.complete(
                  await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => RouteEditorScreen(route: route),
                    ),
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(await result.future, {
      'hostname': 'app.example.com',
      'service': 'http://localhost:8080',
      'path': '/api',
      'originRequest': {
        'access': {'required': true},
        'noTLSVerify': true,
      },
    });
  });
}
