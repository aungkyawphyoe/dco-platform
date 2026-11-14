import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../generated/app_localizations.dart';
import '../router/routes.dart';
import '../theme/dco_tokens.dart';
import 'dco_button.dart';
import 'dco_card.dart';

/// Confirms a local save; synchronization is independent of this screen.
class LogSuccessScreen extends StatelessWidget {
  const LogSuccessScreen({
    super.key,
    required this.title,
    required this.heading,
    required this.details,
  });

  final String title;
  final String heading;
  final List<({String label, String value})> details;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(tokens.space.s5),
                children: [
                  DcoCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: tokens.status.successFg,
                          size: 64,
                        ),
                        SizedBox(height: tokens.space.s3),
                        Text(
                          heading,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: tokens.space.s2),
                        Text(
                          s.logSuccessSubtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.space.s4),
                  DcoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.registerSuccessDetails,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final detail in details) ...[
                          SizedBox(height: tokens.space.s3),
                          Text(
                            detail.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          SizedBox(height: tokens.space.s1),
                          Text(
                            detail.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tokens.space.s4),
              child: DcoButton(
                label: s.registerSuccessBackHome,
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
