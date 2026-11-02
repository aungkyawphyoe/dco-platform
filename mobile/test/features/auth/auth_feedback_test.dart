import 'package:dco_mobile/features/auth/domain/auth_failure.dart';
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
                  strings.apiErrorFlowExpired,
                );
                expect(
                  authFeedback(
                    context,
                    const AccountSecurityException('server_unavailable'),
                  ),
                  strings.apiErrorServer,
                );
                expect(
                  authFeedback(
                    context,
                    const AccountSecurityException('provider_not_configured'),
                  ),
                  strings.apiErrorProviderNotConfigured,
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

  testWidgets('auth failures map to localized connection and API messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final strings = AppLocalizations.of(context)!;
            expect(
              authFeedback(context, const NetworkAuthFailure()),
              strings.apiErrorNetwork,
            );
            expect(
              authFeedback(context, const InvalidCredentialsFailure()),
              strings.apiErrorInvalidCredentials,
            );
            expect(
              authFeedback(context, const RateLimitedFailure()),
              strings.apiErrorRateLimited,
            );
            expect(
              authFeedback(context, const ServiceUnavailableFailure()),
              strings.apiErrorServer,
            );
            expect(
              authFeedback(
                context,
                const ApiAuthFailure('deactivated', 'Account is deactivated'),
              ),
              strings.apiErrorAccountDeactivated,
            );
            expect(
              authFeedback(context, const ApiAuthFailure('invalid_code')),
              strings.apiErrorCodeInvalid,
            );
            expect(
              authFeedback(context, const ApiAuthFailure('some_new_code')),
              strings.apiErrorGeneric,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
