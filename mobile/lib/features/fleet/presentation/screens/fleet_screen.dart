import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class FleetScreen extends StatelessWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: tokens.icon.inactive,
              ),
              SizedBox(height: tokens.space.s4),
              Text(
                s.fleetTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                'Fleet mode and org management coming soon.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
