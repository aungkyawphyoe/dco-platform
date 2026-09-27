import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/presentation/widgets/fleet_widgets.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Org Management → Settings tab. Contact details are managed by the
/// backend admins — read-only here.
class OrgSettingsTab extends ConsumerWidget {
  const OrgSettingsTab({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final orgAsync = ref.watch(myOrganizationProvider);
    final orgCtx = ref.watch(entitlementsProvider).valueOrNull?.organization;
    final org = orgAsync.valueOrNull?.organization;

    if (org == null && orgAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = org?.status ?? orgCtx?.status ?? 'pending';
    final plan = org?.plan ?? orgCtx?.plan ?? '';
    return ListView(
      padding: EdgeInsets.all(tokens.space.s3),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (org?.name.isNotEmpty ?? false)
                            ? org!.name
                            : orgId,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusChip(
                      label: fleetOrgStatusLabel(s, status),
                      tone: orgStatusTone(status),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.s3),
                _Row(label: s.fleetOrgSettingsPlan, value: plan),
                _Row(label: s.fleetOrgSettingsStatus, value: status),
                _Row(
                  label: s.fleetOrgSettingsEmail,
                  value: org?.contactEmail ?? '—',
                ),
                _Row(
                  label: s.fleetOrgSettingsPhone,
                  value: org?.contactPhone ?? '—',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.space.s3),
        Text(
          s.fleetOrgSettingsReadonly,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.text.caption),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
