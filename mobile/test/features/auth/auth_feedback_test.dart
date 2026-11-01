import 'package:dco_mobile/features/auth/domain/repositories/account_security_repository.dart';
import 'package:dco_mobile/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'my']) {
    testWidgets(
      '$language distinguishes recoverable auth failures and quiet cancellation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final strings = AppLocalizations.of(context)!;
                expect(
                  authFeedback(
                    context,
                    const AccountSecurityException('invalid_flow'),
                  ),
                  strings.authFlowExpired,
                );
                expect(
                  authFeedback(
                    context,
                    const AccountSecurityException('server_unavailable'),
                  ),
                  strings.authServiceUnavailable,
                );
                expect(
                  authFeedback(
                    context,
                    const AccountSecurityException('provider_not_configured'),
                  ),
                  strings.authNotConfigured,
                );
                expect(
                  authFeedback(context, PlatformException(code: 'CANCELED')),
                  isEmpty,
                );
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  }
}
