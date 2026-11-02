import 'package:dco_mobile/features/sync/presentation/sync_error_messages.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'my']) {
    testWidgets('$language localizes sync API errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final strings = AppLocalizations.of(context)!;
              expect(
                syncErrorMessage(strings, 'network'),
                strings.syncErrorNetwork,
              );
              expect(
                syncErrorMessage(strings, 'unauthorized'),
                strings.syncErrorSession,
              );
              expect(
                syncErrorMessage(strings, 'LIMIT_EXCEEDED'),
                strings.syncErrorPlan,
              );
              expect(
                syncErrorMessage(strings, 'some_new_code'),
                strings.syncErrorGeneric,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  }
}
