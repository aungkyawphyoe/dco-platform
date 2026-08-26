import 'package:dco_mobile/core/theme/dco_theme.dart';
import 'package:dco_mobile/core/widgets/dco_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('error dialog shows title and message, pops on action', (tester) async {
    var actionCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDcoTheme(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDcoErrorDialog(
                  context,
                  title: 'Sync failed',
                  message: 'Check your connection and try again',
                  actionLabel: 'Retry',
                  onAction: () => actionCalled = true,
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Sync failed'), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    expect(actionCalled, isFalse);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Sync failed'), findsNothing);
    expect(actionCalled, isTrue);
  });
}
