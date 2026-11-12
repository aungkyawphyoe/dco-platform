import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../generated/app_localizations.dart';
import '../../../auth/presentation/session_controller.dart';

/// The signed-in account's identifier as a QR code.
///
/// This identifies the account only. It is not a login, consent, or an
/// invitation to view the garage; an organization still has to prepare and
/// complete a handover before any vehicle moves.
class AccountCodeScreen extends ConsumerWidget {
  const AccountCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;

    return Scaffold(
      appBar: AppBar(title: Text(s.accountCodeTitle)),
      body: user == null
          ? Center(child: CircularProgressIndicator(color: tokens.text.accent))
          : SingleChildScrollView(
              padding: EdgeInsets.all(tokens.space.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.space.s5),
                    decoration: BoxDecoration(
                      color: tokens.background.card,
                      borderRadius: BorderRadius.circular(tokens.radius.lg),
                      border: Border.all(color: tokens.border.defaultColor),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: user.id,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                        SizedBox(height: tokens.space.s4),
                        Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName!
                              : user.email,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: tokens.space.s2),
                        SelectableText(
                          user.id,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.text.secondary,
                                fontFamily: 'IBM Plex Mono',
                              ),
                        ),
                        SizedBox(height: tokens.space.s4),
                        DcoButton(
                          label: s.accountCodeCopy,
                          variant: DcoButtonVariant.secondary,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: user.id),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.accountCodeCopied)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.space.s4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 18,
                        color: tokens.icon.inactive,
                      ),
                      SizedBox(width: tokens.space.s2),
                      Expanded(
                        child: Text(
                          s.accountCodeExplanation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
