import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Warranty templates used for showroom transfers (admin / manager).
class FleetWarrantyTemplatesScreen extends ConsumerWidget {
  const FleetWarrantyTemplatesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String orgId,
    String templateId,
  ) async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.fleetWarrantyDeleteTitle),
        content: Text(s.fleetWarrantyDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(fleetRepositoryProvider)
          .deleteWarrantyTemplate(orgId, templateId);
      ref.invalidate(warrantyTemplatesProvider(orgId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fleetActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;

    if (orgCtx == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.fleetHubWarrantyTemplates)),
        body: DcoEmptyState(
          title: s.fleetNoAccessTitle,
          body: s.fleetNoAccessBody,
        ),
      );
    }
    final orgId = orgCtx.id;
    final canOperate = orgCtx.canOperate;
    final templatesAsync = ref.watch(warrantyTemplatesProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetHubWarrantyTemplates)),
      floatingActionButton: canOperate
          ? FloatingActionButton(
              heroTag: 'btn-fleet-new-warranty',
              tooltip: s.fleetWarrantyNew,
              onPressed: () => context.push(AppRoutes.fleetWarrantyNew),
              child: const Icon(Icons.add),
            )
          : null,
      body: templatesAsync.when(
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
                onAction: () =>
                    ref.invalidate(warrantyTemplatesProvider(orgId)),
              ),
        data: (templates) {
          if (templates.isEmpty) {
            return DcoEmptyState(
              title: s.fleetWarrantyEmpty,
              body: s.fleetWarrantyEmptyBody,
              actionLabel: canOperate ? s.fleetWarrantyNew : null,
              onAction: canOperate
                  ? () => context.push(AppRoutes.fleetWarrantyNew)
                  : null,
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(tokens.space.s3),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: EdgeInsets.only(bottom: tokens.space.s2),
                child: ListTile(
                  leading: Icon(
                    Icons.verified_outlined,
                    color: tokens.icon.inactive,
                  ),
                  title: Text(template.name),
                  subtitle: Text(
                    [
                      s.fleetWarrantyYearsKm(
                        template.durationYears,
                        template.mileageLimitKm,
                      ),
                      if (template.coverageCategories.isNotEmpty)
                        template.coverageCategories.join(', '),
                    ].join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                  ),
                  trailing: canOperate
                      ? IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: tokens.status.dangerFg,
                          ),
                          onPressed: () =>
                              _delete(context, ref, orgId, template.id),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
