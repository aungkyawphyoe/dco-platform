import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_filter_chip.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_incidents_screen.dart';

enum _ReportFilter { all, workOrders, inspections, incidents }

class DriverReportsScreen extends ConsumerStatefulWidget {
  const DriverReportsScreen({super.key});

  @override
  ConsumerState<DriverReportsScreen> createState() =>
      _DriverReportsScreenState();
}

class _DriverReportsScreenState extends ConsumerState<DriverReportsScreen> {
  _ReportFilter _filter = _ReportFilter.all;
  int _incidentPages = 1;

  bool _shows(_ReportFilter type) =>
      _filter == _ReportFilter.all || _filter == type;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgId = ref.watch(entitlementsProvider).valueOrNull?.organization?.id;
    final workOrders = _shows(_ReportFilter.workOrders)
        ? ref.watch(driverWorkOrdersProvider)
        : null;
    final inspections = _shows(_ReportFilter.inspections)
        ? ref.watch(driverInspectionsProvider)
        : null;
    final incidentPages = [
      if (orgId != null && _shows(_ReportFilter.incidents))
        for (var page = 1; page <= _incidentPages; page++)
          ref.watch(driverIncidentsProvider((orgId, page))),
    ];
    final vehicles = {
      for (final vehicle in ref.watch(garageVehiclesProvider).valueOrNull ?? [])
        vehicle.id: vehicle.displayName,
    };
    final seenIncidents = <String>{};
    final entries =
        <({String id, DateTime? time, Widget tile})>[
          for (final work in workOrders?.valueOrNull ?? [])
            (
              id: 'work/${work.id}',
              time: _date(work.reportedAt) ?? _date(work.createdAt),
              tile: _ReportTile(
                icon: Icons.build_outlined,
                type: s.driverReportsWorkOrders,
                title: issueTypeLabel(s, work.issueType),
                description: work.description,
                vehicle: vehicles[work.vehicleId],
                odometer: '${work.odometerKm} km',
                time: _date(work.reportedAt) ?? _date(work.createdAt),
                status: switch (work.status) {
                  'in_progress' => s.fleetWoStatusInProgress,
                  'completed' => s.fleetWoStatusCompleted,
                  _ => s.fleetWoStatusReported,
                },
                tone: workOrderTone(work.status),
              ),
            ),
          for (final inspection in inspections?.valueOrNull ?? [])
            (
              id: 'inspection/${inspection.id}',
              time:
                  _date(inspection.completedAt) ?? _date(inspection.startedAt),
              tile: _ReportTile(
                icon: Icons.checklist_outlined,
                type: s.driverReportsInspections,
                title: inspection.inspectionType == 'post_trip'
                    ? s.driverInspectionTypePost
                    : s.driverInspectionTypePre,
                description: inspection.notes,
                vehicle: vehicles[inspection.vehicleId],
                time:
                    _date(inspection.completedAt) ??
                    _date(inspection.startedAt),
                status: switch (inspection.status) {
                  'completed' => s.driverReportsInspectionPassed,
                  'failed' => s.driverReportsInspectionFailed,
                  _ => s.fleetWoStatusInProgress,
                },
                tone: switch (inspection.status) {
                  'completed' => 'success',
                  'failed' => 'danger',
                  _ => 'info',
                },
              ),
            ),
          for (final page in incidentPages)
            for (final incident in page.valueOrNull?.items ?? [])
              if (seenIncidents.add(incident.id))
                (
                  id: 'incident/${incident.id}',
                  time: incident.eventAt,
                  tile: _ReportTile(
                    icon: Icons.report_problem_outlined,
                    type: s.incidentTitle,
                    title: incidentCategoryLabel(s, incident.category),
                    description: incident.description,
                    vehicle: vehicles[incident.vehicleId],
                    time: incident.eventAt,
                    status: incident.closed ? s.incidentClosed : s.incidentOpen,
                    tone: incident.closed ? 'success' : 'info',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DriverIncidentDetail(
                          orgId: orgId!,
                          incidentId: incident.id,
                        ),
                      ),
                    ),
                  ),
                ),
        ]..sort((left, right) {
          final byTime = (right.time?.millisecondsSinceEpoch ?? 0).compareTo(
            left.time?.millisecondsSinceEpoch ?? 0,
          );
          return byTime == 0 ? left.id.compareTo(right.id) : byTime;
        });

    final sources = [?workOrders, ?inspections, ...incidentPages];
    final loading = sources.any((source) => source.isLoading);
    final failed = sources.any((source) => source.hasError);
    final more = incidentPages.lastOrNull?.valueOrNull?.hasMore ?? false;

    Future<void> refresh() async {
      if (_incidentPages != 1) setState(() => _incidentPages = 1);
      refreshDriverIncidents(ref);
      if (workOrders != null) ref.invalidate(driverWorkOrdersProvider);
      if (inspections != null) ref.invalidate(driverInspectionsProvider);
      await Future.wait<void>([
        if (workOrders != null)
          ref.read(driverWorkOrdersProvider.future).then<void>((_) {}),
        if (inspections != null)
          ref.read(driverInspectionsProvider.future).then<void>((_) {}),
        if (orgId != null && _shows(_ReportFilter.incidents))
          ref
              .read(driverIncidentsProvider((orgId, 1)).future)
              .then<void>((_) {}),
      ]).catchError((Object _, StackTrace _) => <void>[]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.driverReportsTitle)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space.s4,
              vertical: tokens.space.s2,
            ),
            child: Row(
              children: [
                for (final (filter, label) in [
                  (_ReportFilter.all, s.all),
                  (_ReportFilter.workOrders, s.driverReportsWorkOrders),
                  (_ReportFilter.inspections, s.driverReportsInspections),
                  (_ReportFilter.incidents, s.incidentTitle),
                ])
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: tokens.space.s2),
                    child: DcoFilterChip(
                      label: label,
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: tokens.text.accent,
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(tokens.space.s4),
                children: [
                  if (entries.isEmpty && !loading && !failed)
                    Center(
                      child: Text(switch (_filter) {
                        _ReportFilter.workOrders => s.fleetWorkOrdersEmpty,
                        _ReportFilter.inspections => s.driverInspectionsEmpty,
                        _ReportFilter.incidents => s.incidentEmpty,
                        _ => s.driverMyWorkOrdersEmpty,
                      }),
                    ),
                  for (final entry in entries)
                    Padding(
                      key: ValueKey(entry.id),
                      padding: EdgeInsets.only(bottom: tokens.space.s2),
                      child: entry.tile,
                    ),
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (failed)
                    DcoEmptyState(
                      title: s.error,
                      body: s.serviceHistoryLoadError,
                      actionLabel: s.retry,
                      onAction: refresh,
                    ),
                  if (more && !failed)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() => _incidentPages++),
                      child: Text(s.incidentNext),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _date(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.type,
    required this.title,
    required this.time,
    required this.status,
    required this.tone,
    this.description,
    this.vehicle,
    this.odometer,
    this.onTap,
  });

  final IconData icon;
  final String type, title, status, tone;
  final String? description, vehicle, odometer;
  final DateTime? time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metadata = [
      type,
      ?vehicle,
      ?odometer,
      if (time case final date?)
        MaterialLocalizations.of(context).formatMediumDate(date.toLocal()),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: tokens.icon.inactive),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metadata.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (description case final text? when text.isNotEmpty)
              Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: StatusChip(label: status, tone: tone),
        onTap: onTap,
      ),
    );
  }
}
