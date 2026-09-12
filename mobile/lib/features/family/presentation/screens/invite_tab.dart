import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart'
    as family_entities;

class InviteTab extends ConsumerStatefulWidget {
  final family_entities.Family family;

  const InviteTab({super.key, required this.family});

  @override
  ConsumerState<InviteTab> createState() => _InviteTabState();
}

class _InviteTabState extends ConsumerState<InviteTab> {
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final family = widget.family;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.inviteTabHeading,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: tokens.text.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.inviteTabBody,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border.defaultColor),
            ),
            child: Column(
              children: [
                Text(
                  s.inviteTabShareCode,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: tokens.text.tertiary),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  family.shareCode,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: tokens.text.accent,
                    fontFamily: 'IBM Plex Mono',
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: 'dco://family/join?code=${family.shareCode}',
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  s.inviteTabShareCodeHelper,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DcoButton(
                        label: s.inviteTabCopyCode,
                        variant: DcoButtonVariant.secondary,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.inviteTabCodeCopied)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DcoButton(
                        label: s.inviteTabShare,
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: s.inviteTabShareText(family.shareCode),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DcoButton(
                  label: s.inviteTabRegenerateButton,
                  variant: DcoButtonVariant.tertiary,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(s.inviteTabRegenerateTitle),
                        content: Text(
                          s.inviteTabRegenerateBody,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(s.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(s.inviteTabRegenerateAction),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final repo = ref.read(familyRepositoryProvider);
                      await repo.updateFamily(regenerateShareCode: true);
                      if (mounted) ref.invalidate(myFamilyProvider);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.inviteTabCodeExpiryHelper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
