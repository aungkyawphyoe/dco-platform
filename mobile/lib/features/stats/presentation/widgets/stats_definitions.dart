import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// "What do these stats mean?" bottom sheet — one per stats screen, each with
/// plain-language definitions of every KPI on that screen (FRD stats.md).
Future<void> showStatsDefinitions(
  BuildContext context, {
  required String title,
  required List<String> entries,
}) {
  final s = AppLocalizations.of(context)!;
  final tokens = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.background.card,
    isScrollControlled: true,
    builder: (sheetContext) {
      final sheetTokens = sheetContext.tokens;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(sheetTokens.space.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                SizedBox(height: sheetTokens.space.s4),
                for (final entry in entries)
                  Padding(
                    padding: EdgeInsets.only(bottom: sheetTokens.space.s3),
                    child: Text(
                      entry,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: sheetTokens.text.secondary),
                    ),
                  ),
                SizedBox(height: sheetTokens.space.s4),
                DcoButton(
                  key: const Key('stats-definitions-close'),
                  label: s.close,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
