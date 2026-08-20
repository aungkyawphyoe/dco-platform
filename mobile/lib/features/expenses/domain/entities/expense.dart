enum ExpenseCategory {
  fuel,
  maintenance,
  insurance,
  parking,
  tolls,
  parts,
  other;

  String get storage => name;

  String get label => switch (this) {
    ExpenseCategory.fuel => 'Fuel',
    ExpenseCategory.maintenance => 'Maintenance',
    ExpenseCategory.insurance => 'Insurance',
    ExpenseCategory.parking => 'Parking',
    ExpenseCategory.tolls => 'Tolls',
    ExpenseCategory.parts => 'Parts',
    ExpenseCategory.other => 'Other',
  };

  static ExpenseCategory parse(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.storage == value || category.name == value,
      orElse: () => throw FormatException('Unknown expense category: $value'),
    );
  }
}

class ExpenseAssignedPart {
  const ExpenseAssignedPart({
    required this.id,
    required this.partId,
    required this.name,
  });

  final String id;
  final String partId;
  final String name;

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'part_id': partId,
    'name': name,
  };
}

class ExpenseAssignedPartDraft {
  const ExpenseAssignedPartDraft({
    required this.partId,
    required this.name,
  });

  final String partId;
  final String name;
}

class Expense {
  const Expense({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.amount,
    required this.incurredOn,
    required this.updatedAt,
    required this.createdAt,
    this.notes,
    this.receiptLocalPath,
    this.receiptMediaId,
    this.parts = const [],
  });

  final String id;
  final String vehicleId;
  final ExpenseCategory category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
  final String? receiptLocalPath;
  final String? receiptMediaId;
  final List<ExpenseAssignedPart> parts;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get hasReceipt => receiptLocalPath != null && receiptLocalPath!.isNotEmpty;

  String? get notesPreview {
    final value = notes?.trim();
    if (value == null || value.isEmpty) return null;
    final firstLine = value.split('\n').first;
    if (firstLine.length <= 80) return firstLine;
    return '${firstLine.substring(0, 80).trim()}…';
  }

  Map<String, dynamic> toWriteJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'category': category.storage,
    'amount': amount,
    'incurred_on': incurredOn.toIso8601String().split('T').first,
    'notes': notes,
    'receipt_media_id': receiptMediaId,
    'parts': parts.map((part) => part.toWriteJson()).toList(),
  };
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.category,
    required this.amount,
    required this.incurredOn,
    this.notes,
    this.receiptLocalPath,
    this.receiptMediaId,
    this.parts = const [],
  });

  final ExpenseCategory category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
  final String? receiptLocalPath;
  final String? receiptMediaId;
  final List<ExpenseAssignedPartDraft> parts;
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    required this.category,
    required this.amount,
    required this.percent,
  });

  final ExpenseCategory category;
  final double amount;
  final double percent;
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.thisMonth,
    required this.total,
    this.byCategory = const [],
  });

  static const empty = ExpenseSummary(thisMonth: 0, total: 0);

  final double thisMonth;
  final double total;
  final List<ExpenseCategoryTotal> byCategory;

  factory ExpenseSummary.fromExpenses(List<Expense> items, {required DateTime now}) {
    final monthStart = DateTime(now.year, now.month, 1);
    var thisMonth = 0.0;
    var total = 0.0;
    final byCategory = {for (final category in ExpenseCategory.values) category: 0.0};

    for (final item in items) {
      total += item.amount;
      final incurred = DateTime(item.incurredOn.year, item.incurredOn.month, item.incurredOn.day);
      if (!incurred.isBefore(monthStart) &&
          incurred.year == now.year &&
          incurred.month == now.month) {
        thisMonth += item.amount;
      }
      byCategory[item.category] = (byCategory[item.category] ?? 0) + item.amount;
    }

    return ExpenseSummary(
      thisMonth: _money(thisMonth),
      total: _money(total),
      byCategory: [
        for (final category in ExpenseCategory.values)
          if ((byCategory[category] ?? 0) > 0)
            ExpenseCategoryTotal(
              category: category,
              amount: _money(byCategory[category]!),
              percent: total == 0 ? 0 : _percent(byCategory[category]!, total),
            ),
      ],
    );
  }

  static double _money(double value) => (value * 100).roundToDouble() / 100;

  static double _percent(double amount, double total) =>
      (amount / total * 1000).roundToDouble() / 10;
}
