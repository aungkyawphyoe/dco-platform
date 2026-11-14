import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/units/money_format.dart';
import '../../../../core/widgets/log_success_screen.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/expense.dart';

class ExpenseSuccessScreen extends StatelessWidget {
  const ExpenseSuccessScreen({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final category = switch (expense.category) {
      ExpenseCategory.fuel => s.expenseCategoryFuel,
      ExpenseCategory.maintenance => s.expenseCategoryMaintenance,
      ExpenseCategory.insurance => s.expenseCategoryInsurance,
      ExpenseCategory.parking => s.expenseCategoryParking,
      ExpenseCategory.tolls => s.expenseCategoryTolls,
      ExpenseCategory.parts => s.expenseCategoryParts,
      ExpenseCategory.other => s.expenseCategoryOther,
    };
    return LogSuccessScreen(
      title: s.expenseFormAddTitle,
      heading: s.expenseSuccessTitle,
      details: [
        (label: s.expenseFormCategorySheetTitle, value: category),
        (
          label: s.registerServiceDate,
          value: DateFormat.yMMMd(s.localeName).format(expense.incurredOn),
        ),
        (
          label: s.expenseDetailAmount,
          value: MoneyFormat.labeled(expense.amount, expense.currency),
        ),
        if (expense.notes?.trim().isNotEmpty ?? false)
          (label: s.serviceDetailNotes, value: expense.notes!),
      ],
    );
  }
}
