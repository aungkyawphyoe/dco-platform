import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_alert_box.dart';
import '../../../fleet/providers.dart';
import '../../../../core/widgets/dco_logo.dart';
import '../../../../generated/app_localizations.dart';

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final failed = ref.watch(entitlementsProvider).hasError;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DcoLogo(),
              SizedBox(height: tokens.space.s5),
              if (failed) ...[
                DcoAlertBox(
                  title: s.authServiceUnavailable,
                  message: s.authLoadAccessFailed,
                  actionLabel: s.retry,
                  onAction: () => ref.invalidate(entitlementsProvider),
                ),
              ] else
                CircularProgressIndicator(color: tokens.text.accent),
            ],
          ),
        ),
      ),
    );
  }
}
