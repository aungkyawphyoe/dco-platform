import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/money_format.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/expenses/domain/entities/expense.dart';
import 'package:dco_mobile/features/expenses/providers.dart';
import 'package:dco_mobile/features/garage/domain/vehicle_access.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/settings/providers.dart';
import 'package:dco_mobile/features/vehicle_sharing/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final currency = ref.watch(currencyProvider).code;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final currentUserId = ref.watch(currentUserIdProvider);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final expense = expenseAsync.valueOrNull;

    final canEdit =
        expense != null &&
        vehicle != null &&
        VehicleAccess.of(vehicle, currentUserId).canEditRecord(expense.createdBy);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.expenseDetailTitle),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: s.edit,
              icon: Icon(Icons.edit_outlined, color: tokens.icon.inactive),
              onPressed: () async {
                await context.push(AppRoutes.expenseEdit(expenseId));
                if (context.mounted) ref.invalidate(expenseDetailProvider(expenseId));
              },
            ),
        ],
      ),
      body: expenseAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.text.accent),
        ),
        error: (error, stackTrace) => DcoEmptyState(
          title: s.expenseDetailNotFound,
          body: s.expenseDetailNotFoundBody,
        ),
        data: (expense) {
          if (expense == null) {
            return DcoEmptyState(
              title: s.expenseDetailNotFound,
              body: s.expenseDetailNotFoundBody,
            );
          }
          final nameAsync = expense.createdBy == null
              ? null
              : ref.watch(userNameProvider(expense.createdBy!));
          return ListView(
            padding: EdgeInsets.all(tokens.space.s5),
            children: [
              Text(
                _categoryLabel(expense.category, s),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                DateFormat.yMMMd().format(expense.incurredOn),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.secondary,
                ),
              ),
              SizedBox(height: tokens.space.s5),
              _kv(context, s.expenseDetailAmount, MoneyFormat.labeled(expense.amount, currency)),
              if (expense.notes != null && expense.notes!.trim().isNotEmpty)
                _kv(context, s.expenseDetailNotes, expense.notes!),
              if (expense.parts.isNotEmpty)
                _kv(
                  context,
                  s.expenseDetailParts,
                  expense.parts.map((part) => part.name).join(', '),
                ),
              _kv(context, s.loggedBy, nameAsync?.valueOrNull ?? '—'),
            ],
          );
        },
      ),
    );
  }

  String _categoryLabel(ExpenseCategory category, AppLocalizations s) =>
      switch (category) {
        ExpenseCategory.fuel => s.expenseCategoryFuel,
        ExpenseCategory.maintenance => s.expenseCategoryMaintenance,
        ExpenseCategory.insurance => s.expenseCategoryInsurance,
        ExpenseCategory.parking => s.expenseCategoryParking,
        ExpenseCategory.tolls => s.expenseCategoryTolls,
        ExpenseCategory.parts => s.expenseCategoryParts,
        ExpenseCategory.other => s.expenseCategoryOther,
      };

  Widget _kv(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: tokens.space.s1),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
