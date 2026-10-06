import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_button.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/vehicle_share.dart';

/// The Code/QR half of vehicle sharing: current code, QR, copy/share,
/// and regenerate.
class ShareCodePanel extends StatelessWidget {
  const ShareCodePanel({
    super.key,
    required this.detail,
    required this.loading,
    required this.onGenerate,
    required this.onRegenerate,
  });

  final VehicleSharesDetail? detail;
  final bool loading;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final code = detail?.effectiveShareCode;

    if (code == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, size: 64, color: tokens.icon.inactive),
              SizedBox(height: tokens.space.s3),
              Text(
                s.shareCodeHelper,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
              ),
              SizedBox(height: tokens.space.s4),
              DcoButton(
                label: s.shareRegenerate,
                loading: loading,
                onPressed: onGenerate,
              ),
            ],
          ),
        ),
      );
    }

    final joinUrl = 'dco://vehicle/share/join?code=$code';
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(tokens.space.s4),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.lg),
              border: Border.all(color: tokens.border.defaultColor),
            ),
            child: Column(
              children: [
                Text(
                  s.shareCodeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: tokens.text.tertiary),
                ),
                SizedBox(height: tokens.space.s2),
                SelectableText(
                  code,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: tokens.text.accent,
                    fontFamily: 'IBM Plex Mono',
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.space.s3),
                QrImageView(
                  data: joinUrl,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                SizedBox(height: tokens.space.s2),
                Text(
                  s.shareQrHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
                ),
                SizedBox(height: tokens.space.s3),
                Row(
                  children: [
                    Expanded(
                      child: DcoButton(
                        label: s.shareCodeCopied,
                        variant: DcoButtonVariant.secondary,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.shareCodeCopied)),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(width: tokens.space.s3),
                    Expanded(
                      child: DcoButton(
                        label: s.share,
                        onPressed: () =>
                            SharePlus.instance.share(ShareParams(text: joinUrl)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.s2),
                DcoButton(
                  label: s.shareRegenerate,
                  variant: DcoButtonVariant.tertiary,
                  onPressed: onRegenerate,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.space.s3),
          Text(
            s.shareCodeExpiry,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
          ),
        ],
      ),
    );
  }
}
