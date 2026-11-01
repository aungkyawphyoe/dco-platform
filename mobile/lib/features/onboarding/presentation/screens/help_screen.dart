import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../tour_controller.dart';

/// Settings → Help. Hosts the explicit tour replay now; FAQ content is a
/// separate follow-up.
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
    return Scaffold(
      appBar: AppBar(title: Text(s.helpTitle)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
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
        ],
      ),
    );
  }
}
