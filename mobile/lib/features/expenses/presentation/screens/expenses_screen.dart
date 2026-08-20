import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpenseCategory? _category;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final expenses = ref.watch(vehicleExpensesProvider);
    final summary = ref.watch(vehicleExpenseSummaryProvider).valueOrNull ?? ExpenseSummary.empty;
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Add expense',
            onPressed: vehicle == null ? null : () => context.push(AppRoutes.expenseNew),
            icon: Icon(Icons.add, color: vehicle == null ? tokens.icon.inactive : tokens.icon.active),
          ),
        ],
      ),
      body: vehicle == null
          ? const DcoEmptyState(
              title: 'No active vehicle',
              body: 'Register a vehicle to log spend. Fuel here is money only — not a fuel log.',
            )
          : expenses.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: 'Could not load expenses', body: '$error'),
              data: (items) {
                final filtered = _category == null
                    ? items
                    : items.where((item) => item.category == _category).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryHeader(summary: summary, currency: currency),
                    if (items.isNotEmpty) ...[
                      if (summary.byCategory.isNotEmpty)
                        _CategoryBreakdown(summary: summary, currency: currency),
                      _CategoryFilterBar(
                        selected: _category,
                        onSelected: (category) => setState(() => _category = category),
                      ),
                    ],
                    Expanded(
                      child: items.isEmpty
                          ? DcoEmptyState(
                              title: 'No expenses yet',
                              body: 'Log spend for ${vehicle.displayName}. Fuel is money only — not a fuel log.',
                              actionLabel: 'Add expense',
                              onAction: () => context.push(AppRoutes.expenseNew),
                            )
                          : filtered.isEmpty
                          ? const DcoEmptyState(
                              title: 'No matching expenses',
                              body: 'Try a different category.',
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                tokens.space.s4,
                                tokens.space.s2,
                                tokens.space.s4,
                                tokens.space.s5,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final expense = filtered[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: tokens.space.s3),
                                  child: _ExpenseTile(
                                    expense: expense,
                                    currency: currency,
                                    onTap: () => context.push(AppRoutes.expenseEdit(expense.id)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary, required this.currency});

  final ExpenseSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, tokens.space.s3, tokens.space.s4, tokens.space.s2),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(label: 'This month', value: MoneyFormat.labeled(summary.thisMonth, currency)),
          ),
          SizedBox(width: tokens.space.s3),
          Expanded(
            child: _SummaryCard(label: 'Total', value: MoneyFormat.labeled(summary.total, currency)),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption)),
          SizedBox(height: tokens.space.s2),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(color: tokens.text.primary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary, required this.currency});

  final ExpenseSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, tokens.space.s2, tokens.space.s4, tokens.space.s2),
      child: Column(
        children: [
          for (final slice in summary.byCategory)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space.s2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: slice.category.color(tokens),
                      borderRadius: BorderRadius.circular(tokens.radius.full),
                    ),
                  ),
                  SizedBox(width: tokens.space.s2),
                  Expanded(
                    child: Text(slice.category.label, style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Text(
                    '${slice.percent.toStringAsFixed(slice.percent == slice.percent.roundToDouble() ? 0 : 1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  SizedBox(width: tokens.space.s3),
                  Text(
                    MoneyFormat.labeled(slice.amount, currency),
                    style: GoogleFonts.ibmPlexMono(color: tokens.text.secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onSelected});

  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.space.s4, tokens.space.s2, tokens.space.s4, tokens.space.s2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelected(null),
            ),
            for (final category in ExpenseCategory.values) ...[
              SizedBox(width: tokens.space.s2),
              _FilterChip(
                label: category.label,
                selected: selected == category,
                onTap: () => onSelected(category),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.text.accent : tokens.background.input,
      borderRadius: BorderRadius.circular(tokens.radius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space.s3),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? tokens.text.onAccent : tokens.text.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.currency,
    required this.onTap,
  });

  final Expense expense;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = expense.category.color(tokens);
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(expense.category.icon, color: color, size: 22),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(expense.incurredOn),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                    ),
                    SizedBox(height: tokens.space.s1),
                    Text(expense.category.label, style: Theme.of(context).textTheme.titleMedium),
                    if (expense.notesPreview != null) ...[
                      SizedBox(height: tokens.space.s1),
                      Text(
                        expense.notesPreview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyFormat.labeled(expense.amount, currency),
                    style: GoogleFonts.ibmPlexMono(color: tokens.text.secondary, fontSize: 13),
                  ),
                  if (expense.hasReceipt) ...[
                    SizedBox(height: tokens.space.s1),
                    Icon(Icons.photo_outlined, size: 16, color: tokens.icon.inactive),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ExpenseCategoryStyle on ExpenseCategory {
  Color color(DcoTokens tokens) => switch (this) {
    ExpenseCategory.fuel => tokens.chart.fuel,
    ExpenseCategory.maintenance => tokens.chart.maintenance,
    ExpenseCategory.insurance => tokens.chart.insurance,
    ExpenseCategory.parking => tokens.chart.parking,
    ExpenseCategory.tolls => tokens.chart.tolls,
    ExpenseCategory.parts => tokens.chart.parts,
    ExpenseCategory.other => tokens.chart.other,
  };

  IconData get icon => switch (this) {
    ExpenseCategory.fuel => Icons.local_gas_station_outlined,
    ExpenseCategory.maintenance => Icons.build_outlined,
    ExpenseCategory.insurance => Icons.shield_outlined,
    ExpenseCategory.parking => Icons.local_parking_outlined,
    ExpenseCategory.tolls => Icons.alt_route_outlined,
    ExpenseCategory.parts => Icons.settings_outlined,
    ExpenseCategory.other => Icons.payments_outlined,
  };
}
