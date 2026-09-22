import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class ExpenseStatsScreen extends StatelessWidget {
  const ExpenseStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(s.expenseStatsTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 64,
                color: tokens.icon.inactive,
              ),
              SizedBox(height: tokens.space.s4),
              Text(
                s.expenseStatsTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                'Charts for spending by category, monthly trends, and lifetime summary coming soon.',
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
