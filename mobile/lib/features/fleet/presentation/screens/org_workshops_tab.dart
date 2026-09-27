import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `GET /organizations/:id/workshops` — approved workshop network.
/// Admin/manager only (403 → "no access" empty state).
class OrgWorkshopsTab extends ConsumerWidget {
  const OrgWorkshopsTab({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final workshopsAsync = ref.watch(orgWorkshopsProvider(orgId));

    return workshopsAsync.when(
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
              onAction: () => ref.invalidate(orgWorkshopsProvider(orgId)),
            ),
      data: (workshops) {
        if (workshops.isEmpty) {
          return DcoEmptyState(
            title: s.fleetOrgWorkshopsEmpty,
            body: s.fleetOrgWorkshopsEmpty,
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(tokens.space.s3),
          itemCount: workshops.length,
          itemBuilder: (context, index) {
            final workshop = workshops[index];
            return Card(
              margin: EdgeInsets.only(bottom: tokens.space.s2),
              child: ListTile(
                leading: Icon(Icons.handyman, color: tokens.icon.inactive),
                title: Text(workshop.name),
                subtitle: workshop.contactEmail == null
                    ? null
                    : Text(
                        workshop.contactEmail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.caption,
                        ),
                      ),
                trailing: StatusChip(
                  label: fleetOrgStatusLabel(s, workshop.status),
                  tone: orgStatusTone(workshop.status),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
