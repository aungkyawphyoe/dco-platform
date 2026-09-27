import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fleet mode Expenses tab: per-vehicle metrics, fleet summary, lemon flags,
/// and CSV export (FRD §17 analytics endpoints).
class FleetReportsScreen extends ConsumerStatefulWidget {
  const FleetReportsScreen({super.key});

  @override
  ConsumerState<FleetReportsScreen> createState() =>
      _FleetReportsScreenState();
}

class _FleetReportsScreenState extends ConsumerState<FleetReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(String orgId) async {
    final s = AppLocalizations.of(context)!;
    final type = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(s.fleetReportsExport),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'vehicles'),
            child: Text(s.fleetInventoryTitle),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'fleet'),
            child: Text(s.fleetReportsTabFleet),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'lemons'),
            child: Text(s.fleetReportsTabLemons),
          ),
        ],
      ),
    );
    if (type == null) return;
    try {
      final csv = await ref
          .read(fleetRepositoryProvider)
          .exportReportCsv(orgId, type);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetReportsExport)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return DcoEmptyState(
        title: s.fleetNoAccessTitle,
        body: s.fleetNoAccessBody,
      );
    }
    final orgId = orgCtx.id;

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(
        title: Text(s.fleetReportsTitle),
        actions: [
          if (orgCtx.canOperate)
            IconButton(
              tooltip: s.fleetReportsExport,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _exportCsv(orgId),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: tokens.text.accent,
          unselectedLabelColor: tokens.text.tertiary,
          indicatorColor: tokens.text.accent,
          tabs: [
            Tab(text: s.fleetReportsTabVehicles),
            Tab(text: s.fleetReportsTabFleet),
            Tab(text: s.fleetReportsTabLemons),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PerVehicleTab(orgId: orgId),
          _FleetSummaryTab(orgId: orgId),
          _LemonsTab(orgId: orgId),
        ],
      ),
    );
  }
}

class _PerVehicleTab extends ConsumerWidget {
  const _PerVehicleTab({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final analyticsAsync = ref.watch(fleetAnalyticsProvider(orgId));

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => error is FleetAccessDenied
          ? DcoEmptyState(
              title: s.fleetOrgNotPermitted,
              body: s.fleetOrgNotPermittedBody,
            )
          : DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(fleetAnalyticsProvider(orgId)),
            ),
      data: (analytics) {
        if (analytics.vehicles.isEmpty) {
          return DcoEmptyState(
            title: s.fleetReportsEmpty,
            body: s.fleetInventoryEmptyBody,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(tokens.space.s3),
          itemCount: analytics.vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = analytics.vehicles[index];
            return Card(
              margin: EdgeInsets.only(bottom: tokens.space.s2),
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  color: tokens.icon.inactive,
                ),
                title: Text(vehicle.name ?? vehicle.vehicleId),
                subtitle: Text(
                  [
                    vehicle.licensePlate ?? '',
                    '${s.fleetReportsCostPerKmShort}: '
                        '${vehicle.costPerKm.toStringAsFixed(2)}',
                    '${s.fleetReportsKm}: ${vehicle.totalKmDriven}',
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                ),
                trailing: StatusChip(
                  label:
                      '${s.fleetReportsTco}: ${vehicle.tco.round()}',
                  tone: 'info',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FleetSummaryTab extends ConsumerWidget {
  const _FleetSummaryTab({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final analyticsAsync = ref.watch(fleetAnalyticsProvider(orgId));

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => error is FleetAccessDenied
          ? DcoEmptyState(
              title: s.fleetOrgNotPermitted,
              body: s.fleetOrgNotPermittedBody,
            )
          : DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(fleetAnalyticsProvider(orgId)),
            ),
      data: (analytics) => ListView(
        padding: EdgeInsets.all(tokens.space.s3),
        children: [
          _MetricCard(
            label: s.fleetReportsSpend,
            value: analytics.totalFleetSpend.round().toString(),
          ),
          _MetricCard(
            label: s.fleetReportsCostPerKm,
            value: analytics.averageCostPerKm.toStringAsFixed(2),
          ),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: s.fleetReportsVehicles,
                  value: analytics.vehicleCount.toString(),
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: _MetricCard(
                  label: s.fleetReportsLemons,
                  value: analytics.lemonCount.toString(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: s.fleetReportsOpenWorkOrders,
                  value: analytics.openWorkOrders.toString(),
                ),
              ),
              SizedBox(width: tokens.space.s2),
              Expanded(
                child: _MetricCard(
                  label: s.fleetReportsAssignments,
                  value: analytics.activeAssignments.toString(),
                ),
              ),
            ],
          ),
          _MetricCard(
            label: s.fleetReportsUpcoming,
            value: analytics.upcomingMaintenanceCount.toString(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      margin: EdgeInsets.only(bottom: tokens.space.s2),
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
            SizedBox(height: tokens.space.s1),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _LemonsTab extends ConsumerWidget {
  const _LemonsTab({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lemonsAsync = ref.watch(lemonsProvider(orgId));

    return lemonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => error is FleetAccessDenied
          ? DcoEmptyState(
              title: s.fleetOrgNotPermitted,
              body: s.fleetOrgNotPermittedBody,
            )
          : DcoEmptyState(
              title: s.error,
              body: error.toString(),
              actionLabel: s.retry,
              onAction: () => ref.invalidate(lemonsProvider(orgId)),
            ),
      data: (report) {
        if (report.items.isEmpty) {
          return DcoEmptyState(
            title: s.fleetReportsNoLemons,
            body: s.fleetReportsNoLemonsBody,
          );
        }
        return ListView(
          padding: EdgeInsets.all(tokens.space.s3),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space.s2),
              child: Text(
                '${s.fleetReportsThreshold}: '
                '${report.thresholdCostPerKm.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
              ),
            ),
            for (final vehicle in report.items)
              Card(
                margin: EdgeInsets.only(bottom: tokens.space.s2),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: tokens.status.warningFg,
                  ),
                  title: Text(vehicle.name ?? vehicle.vehicleId),
                  subtitle: Text(
                    '${vehicle.licensePlate ?? ''} · '
                    '${s.fleetReportsCostPerKmShort}: '
                    '${vehicle.costPerKm.toStringAsFixed(2)} · '
                    '${s.fleetReportsTco}: ${vehicle.tco.round()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.caption,
                    ),
                  ),
                  trailing: StatusChip(
                    label: s.fleetReportsLemons,
                    tone: 'warning',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
