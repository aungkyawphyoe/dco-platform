import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/units/mileage_format.dart';
import '../../../../core/widgets/dco_empty_state.dart';
import '../../../../generated/app_localizations.dart';
import '../../../garage/providers.dart';
import '../../../maintenance/domain/entities/plan_item.dart';
import '../../../maintenance/providers.dart';
import '../../../settings/providers.dart';
import '../../domain/entities/handover_receipt.dart';
import '../../domain/entities/vehicle_warranty.dart';
import '../../providers.dart';

/// Read-only record of a showroom-to-personal handover: what the buyer
/// received, the copied plan, and the frozen warranty terms.
class HandoverReceiptScreen extends ConsumerWidget {
  const HandoverReceiptScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId)).valueOrNull;
    final receipt = ref
        .watch(vehicleHandoverReceiptProvider(vehicleId))
        .valueOrNull;
    final warranty = ref.watch(vehicleWarrantyProvider(vehicleId)).valueOrNull;
    final plan =
        ref.watch(maintenancePlanForVehicleProvider(vehicleId)).valueOrNull ??
        const <PlanItem>[];
    final lengthUnit = ref.watch(lengthUnitProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.handoverReceiptTitle)),
      body: receipt == null
          ? DcoEmptyState(
              title: s.handoverReceiptNotFound,
              body: s.handoverReceiptNotFoundBody,
            )
          : ListView(
              padding: EdgeInsets.all(tokens.space.s4),
              children: [
                _SectionCard(
                  title: vehicle == null
                      ? s.handoverReceiptTitle
                      : vehicle.yearMakeModel,
                  children: [
                    _row(
                      context,
                      tokens,
                      s.handoverReceiptSaleDate,
                      receipt.saleDate == null
                          ? '—'
                          : DateFormat.yMMMd().format(receipt.saleDate!),
                    ),
                    if (receipt.currentMileageKm != null)
                      _row(
                        context,
                        tokens,
                        s.handoverReceiptMileage,
                        MileageFormat.labeled(
                          lengthUnit.toStorage(receipt.currentMileageKm!),
                          lengthUnit,
                        ),
                      ),
                    _row(
                      context,
                      tokens,
                      s.handoverReceiptStatus,
                      receipt.status == 'completed'
                          ? s.handoverReceiptCompleted
                          : receipt.status,
                    ),
                    if (receipt.completedAt != null)
                      _row(
                        context,
                        tokens,
                        s.handoverReceiptCompletedOn,
                        DateFormat.yMMMd().add_jm().format(
                          receipt.completedAt!.toLocal(),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: tokens.space.s3),
                _SectionCard(
                  title: s.handoverReceiptPlan,
                  children: _planRows(context, tokens, s, receipt, plan),
                ),
                if (warranty != null) ...[
                  SizedBox(height: tokens.space.s3),
                  _WarrantyCard(warranty: warranty),
                ],
                SizedBox(height: tokens.space.s3),
                Container(
                  padding: EdgeInsets.all(tokens.space.s3),
                  decoration: BoxDecoration(
                    color: tokens.background.secondary,
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: tokens.icon.inactive,
                      ),
                      SizedBox(width: tokens.space.s2),
                      Expanded(
                        child: Text(
                          s.handoverReceiptHistoryNote,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _planRows(
    BuildContext context,
    DcoTokens tokens,
    AppLocalizations s,
    HandoverReceipt receipt,
    List<PlanItem> plan,
  ) {
    if (receipt.planItemIds.isEmpty) {
      return [
        Text(
          s.handoverReceiptNoPlan,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
        ),
      ];
    }
    final byId = {for (final item in plan) item.id: item};
    return [
      for (final id in receipt.planItemIds)
        Padding(
          padding: EdgeInsets.only(bottom: tokens.space.s2),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: tokens.status.successFg,
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: Text(
                  byId[id]?.name ?? s.handoverReceiptPlanItem,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (byId[id]?.initialServiceRequired ?? false)
                Text(
                  s.handoverReceiptInitialService,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: tokens.status.infoFg),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _row(
    BuildContext context,
    DcoTokens tokens,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.warranty});

  final VehicleWarranty warranty;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final coverage = warranty.coverageCategories;
    final workshops = warranty.approvedWorkshops;
    return _SectionCard(
      title: s.handoverReceiptWarranty,
      children: [
        if (warranty.name != null)
          Text(warranty.name!, style: Theme.of(context).textTheme.titleMedium),
        if (warranty.durationYears != null)
          Padding(
            padding: EdgeInsets.only(top: tokens.space.s1),
            child: Text(
              s.handoverReceiptWarrantyDuration(warranty.durationYears!),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
            ),
          ),
        if (warranty.mileageLimitKm != null)
          Text(
            s.handoverReceiptWarrantyMileage(
              NumberFormat('#,###').format(warranty.mileageLimitKm!.round()),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary),
          ),
        if (coverage.isNotEmpty) ...[
          SizedBox(height: tokens.space.s2),
          Text(
            s.handoverReceiptWarrantyCoverage,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: tokens.text.tertiary),
          ),
          SizedBox(height: tokens.space.s1),
          Wrap(
            spacing: tokens.space.s1,
            runSpacing: tokens.space.s1,
            children: [
              for (final item in coverage)
                Chip(label: Text(item), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
        if (warranty.exclusions != null && warranty.exclusions!.isNotEmpty) ...[
          SizedBox(height: tokens.space.s2),
          _LabelValue(
            label: s.handoverReceiptWarrantyExclusions,
            value: warranty.exclusions!,
          ),
        ],
        if (workshops.isNotEmpty) ...[
          SizedBox(height: tokens.space.s2),
          _LabelValue(
            label: s.handoverReceiptWarrantyWorkshops,
            value: workshops.map((workshop) => workshop.name).join(', '),
          ),
        ],
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: tokens.text.tertiary),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: tokens.text.tertiary),
          ),
          SizedBox(height: tokens.space.s3),
          ...children,
        ],
      ),
    );
  }
}
