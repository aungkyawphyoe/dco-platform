import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../tour_controller.dart';
import '../../../../core/providers.dart';
import '../widgets/feedback_card.dart';

/// Offline help and explicit, user-controlled feedback.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  void _replayTour() {
    ref.read(tourControllerProvider.notifier).start(tourStepsFor());
    // Return to a stable Garage dashboard before the first hint measures its
    // anchor. Tab stacks are preserved by the indexed shell.
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final driver = ref.watch(driverOrganizationIdProvider) != null;
    final questions = [
      (s.helpLoginQuestion, s.helpLoginAnswer),
      (
        s.helpVehicleQuestion,
        driver ? s.helpDriverVehicleAnswer : s.helpVehicleAnswer,
      ),
      (s.helpMaintenanceQuestion, s.helpMaintenanceAnswer),
      (s.helpExpensesQuestion, s.helpExpensesAnswer),
      (s.helpSyncQuestion, s.helpSyncAnswer),
      (s.helpNotesQuestion, s.helpNotesAnswer),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.helpTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Text(
            s.helpOfflineIntro,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.text.caption),
          ),
          SizedBox(height: tokens.space.s4),
          DcoCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radius.lg),
              ),
              leading: Icon(Icons.tour_outlined, color: tokens.icon.inactive),
              title: Text(s.helpReplayTour),
              subtitle: Text(
                s.helpReplayTourBody,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
              ),
              trailing: Icon(Icons.chevron_right, color: tokens.icon.inactive),
              onTap: _replayTour,
            ),
          ),
          SizedBox(height: tokens.space.s6),
          Semantics(
            header: true,
            child: Text(
              s.helpFaqTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(height: tokens.space.s3),
          for (var i = 0; i < questions.length; i++) ...[
            DcoCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: PageStorageKey('help-faq-$i-$driver'),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(questions[i].$1),
                childrenPadding: EdgeInsets.fromLTRB(
                  tokens.space.s4,
                  0,
                  tokens.space.s4,
                  tokens.space.s4,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questions[i].$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.text.caption,
                    ),
                  ),
                  if (i == 4)
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.sync),
                      icon: const Icon(Icons.sync),
                      label: Text(s.helpSyncAction),
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.space.s3),
          ],
          SizedBox(height: tokens.space.s3),
          const FeedbackCard(),
        ],
      ),
    );
  }
}
