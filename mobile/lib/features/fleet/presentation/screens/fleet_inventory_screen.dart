import 'dart:async';

import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/presentation/screens/fleet_vehicle_list.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Fleet mode Garage tab: org vehicle inventory with add + CSV import.
class FleetInventoryScreen extends ConsumerWidget {
  const FleetInventoryScreen({super.key});

  Future<void> _importCsv(
    BuildContext context,
    WidgetRef ref,
    String orgId,
  ) async {
    final s = AppLocalizations.of(context)!;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    final file = files.firstOrNull;
    if (file == null || !context.mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    final repository = ref.read(fleetRepositoryProvider);
    try {
      final bytes = await file.readAsBytes();
      final import = await repository.importVehiclesCsv(
        orgId,
        bytes,
        file.name,
      );
      var job = await repository.getImportJob(orgId, import.jobId);
      for (
        var attempt = 0;
        job != null && job.status == 'processing';
        attempt++
      ) {
        if (attempt >= 10) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        job = await repository.getImportJob(orgId, import.jobId);
      }
      ref.invalidate(orgVehiclesProvider(orgId));
      if (rootNavigator.mounted) rootNavigator.pop(); // loading dialog
      if (!context.mounted) return;
      final message = job == null || job.status == 'processing'
          ? s.fleetInventoryImportStarted(import.totalRows)
          : s.fleetInventoryImportResult(job.successCount, job.failCount);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (rootNavigator.mounted) rootNavigator.pop(); // loading dialog
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final canOperate = orgCtx.canOperate;

    return Scaffold(
      backgroundColor: tokens.background.primary,
      appBar: AppBar(
        title: Text(s.fleetInventoryTitle),
        actions: [
          if (canOperate)
            IconButton(
              tooltip: s.fleetInventoryImport,
              icon: const Icon(Icons.upload_file),
              onPressed: () => _importCsv(context, ref, orgId),
            ),
        ],
      ),
      floatingActionButton: canOperate
          ? FloatingActionButton(
              heroTag: 'btn-fleet-add-inventory',
              tooltip: s.fleetInventoryAdd,
              onPressed: () => context.push(AppRoutes.fleetVehicleNew),
              child: const Icon(Icons.add),
            )
          : null,
      body: FleetVehicleList(
        orgId: orgId,
        onAdd: canOperate
            ? () => context.push(AppRoutes.fleetVehicleNew)
            : null,
        onImport: canOperate ? () => _importCsv(context, ref, orgId) : null,
      ),
    );
  }
}
