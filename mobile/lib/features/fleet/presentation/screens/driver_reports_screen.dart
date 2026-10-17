import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/entities/inspection.dart';
import 'package:dco_mobile/features/fleet/domain/entities/work_order.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Driver pushed Reports screen (Confirmed Access Decisions 16/20/44).
///
/// Two sections, both driver-scoped and online-first:
///
/// * **Work orders** — the driver's own Report-Issue work orders with
///   status chips (reported → in_progress → completed). Maintenance-Report
///   work orders are deliberately excluded — they live in Maintenance
///   history (Decision 44: no duplicates across feeds).
/// * **Inspections** — the driver's own inspections (pre/post-trip) with
///   passed / failed / in-progress chips.
class DriverReportsScreen extends ConsumerWidget {
  const DriverReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final workOrdersAsync = ref.watch(driverWorkOrdersProvider);
    final inspectionsAsync = ref.watch(driverInspectionsProvider);

    final issueWorkOrders = (workOrdersAsync.valueOrNull ?? const [])
        .where((wo) => wo.issueType != 'scheduled_service')
        .toList()
      ..sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));
    final inspections = [...(inspectionsAsync.valueOrNull ?? const [])]
      ..sort((a, b) => _inspectionTimestamp(b).compareTo(_inspectionTimestamp(a)));

    final isLoading =
        workOrdersAsync.isLoading && inspectionsAsync.isLoading;
    final hasError = workOrdersAsync.hasError && inspectionsAsync.hasError;
    final isEmpty =
        issueWorkOrders.isEmpty && inspections.isEmpty && !isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(s.driverReportsTitle)),
      body: hasError
          ? DcoEmptyState(
              title: s.error,
              body: s.serviceHistoryLoadError,
              actionLabel: s.retry,
              onAction: () {
                ref.invalidate(driverWorkOrdersProvider);
                ref.invalidate(driverInspectionsProvider);
              },
            )
          : isEmpty
              ? DcoEmptyState(
                  title: s.driverMyWorkOrdersEmpty,
                  body: s.driverMyWorkOrdersEmptyBody,
                )
              : RefreshIndicator(
                  color: tokens.text.accent,
                  onRefresh: () async {
                    ref.invalidate(driverWorkOrdersProvider);
                    ref.invalidate(driverInspectionsProvider);
                    await Future.wait([
                      ref.read(driverWorkOrdersProvider.future),
                      ref.read(driverInspectionsProvider.future),
                    ]);
                  },
                  child: ListView(
                    padding: EdgeInsets.all(tokens.space.s4),
                    children: [
                      if (issueWorkOrders.isNotEmpty) ...[
                        SectionHeader(s.driverReportsWorkOrders),
                        if (workOrdersAsync.isLoading && issueWorkOrders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          ...issueWorkOrders.map(
                            (wo) => Card(
                              margin:
                                  EdgeInsets.only(bottom: tokens.space.s2),
                              child: ListTile(
                                leading: Icon(
                                  Icons.report_problem_outlined,
                                  color: tokens.icon.inactive,
                                ),
                                title: Text(issueTypeLabel(s, wo.issueType)),
                                subtitle: Text(
                                  [
                                    wo.description,
                                    DateFormat.yMMMd().format(
                                      DateTime.tryParse(wo.reportedAt ?? '') ??
                                          DateTime.now(),
                                    ),
                                    '${wo.odometerKm} km',
                                  ].where((part) => part.isNotEmpty).join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: tokens.text.caption),
                                ),
                                trailing: StatusChip(
                                  label: _workOrderStatusLabel(s, wo.status),
                                  tone: workOrderTone(wo.status),
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (inspections.isNotEmpty) ...[
                        SectionHeader(s.driverReportsInspections),
                        if (inspectionsAsync.isLoading && inspections.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          ...inspections.map(
                            (inspection) => Card(
                              margin:
                                  EdgeInsets.only(bottom: tokens.space.s2),
                              child: ListTile(
                                leading: Icon(
                                  Icons.checklist_outlined,
                                  color: tokens.icon.inactive,
                                ),
                                title: Text(
                                  inspection.inspectionType == 'post_trip'
                                      ? s.driverInspectionTypePost
                                      : s.driverInspectionTypePre,
                                ),
                                subtitle: Text(
                                  [
                                    DateFormat.yMMMd().format(
                                      DateTime.tryParse(
                                            inspection.completedAt ??
                                                inspection.startedAt ??
                                                '',
                                          ) ??
                                          DateTime.now(),
                                    ),
                                    if (inspection.notes != null &&
                                        inspection.notes!.isNotEmpty)
                                      inspection.notes!,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: tokens.text.caption),
                                ),
                                trailing: StatusChip(
                                  label: inspection.status == 'completed'
                                      ? s.driverReportsInspectionPassed
                                      : inspection.status == 'failed'
                                          ? s.driverReportsInspectionFailed
                                          : s.fleetWoStatusInProgress,
                                  tone: inspection.status == 'completed'
                                      ? 'success'
                                      : inspection.status == 'failed'
                                          ? 'danger'
                                          : 'info',
                                ),
                              ),
                            ),
                          ),
                      ],
                      SizedBox(height: tokens.space.s6),
                    ],
                  ),
                ),
    );
  }

  static DateTime _timestamp(WorkOrder wo) =>
      DateTime.tryParse(wo.reportedAt ?? '') ??
      DateTime.tryParse(wo.createdAt ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _inspectionTimestamp(Inspection inspection) =>
      DateTime.tryParse(inspection.completedAt ?? '') ??
      DateTime.tryParse(inspection.startedAt ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String _workOrderStatusLabel(AppLocalizations s, String status) {
    return switch (status) {
      'in_progress' => s.fleetWoStatusInProgress,
      'completed' => s.fleetWoStatusCompleted,
      _ => s.fleetWoStatusReported,
    };
  }
}
