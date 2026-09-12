import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/features/parts/domain/entities/part.dart';
import 'package:dco_mobile/features/parts/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PartsScreen extends ConsumerWidget {
  const PartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final parts = ref.watch(vehiclePartsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.partsTitle),
        actions: [
          IconButton(
            tooltip: s.partsAddTooltip,
            onPressed: vehicle == null ? null : () => context.push(AppRoutes.partNew),
            icon: Icon(Icons.add, color: vehicle == null ? tokens.icon.inactive : tokens.icon.active),
          ),
        ],
      ),
      body: vehicle == null
          ? DcoEmptyState(
              title: s.partsNoActiveVehicle,
              body: s.partsNoActiveVehicleBody,
            )
          : parts.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (error, _) => DcoEmptyState(title: s.partsLoadError, body: '$error'),
              data: (items) {
                if (items.isEmpty) {
                  return DcoEmptyState(
                    title: s.partsEmptyTitle,
                    body: s.partsEmptyBody(vehicle.displayName),
                    actionLabel: s.partsAddPart,
                    onAction: () => context.push(AppRoutes.partNew),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    tokens.space.s4,
                    tokens.space.s3,
                    tokens.space.s4,
                    tokens.space.s5,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final part = items[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: tokens.space.s3),
                      child: _PartTile(
                        part: part,
                        onTap: () => context.push(AppRoutes.partEdit(part.id)),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({required this.part, required this.onTap});

  final Part part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final detail = part.detailLine;
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.chart.parts.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(Icons.settings_outlined, color: tokens.chart.parts, size: 22),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part.name, style: Theme.of(context).textTheme.titleMedium),
                    if (detail != null) ...[
                      SizedBox(height: tokens.space.s1),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.icon.inactive),
            ],
          ),
        ),
      ),
    );
  }
}
