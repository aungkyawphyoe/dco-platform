import 'dart:io';

import 'package:dco_mobile/core/theme/dco_layout.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum _VehicleMenuAction { edit, share }

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.isActive,
    required this.onOpen,
    this.lengthUnit = MileageUnit.km,
    this.onSetActive,
    this.onEdit,
    this.onShare,
  });

  final Vehicle vehicle;
  final bool isActive;
  final VoidCallback onOpen;
  final MileageUnit lengthUnit;
  final VoidCallback? onSetActive;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);
    final hasMenu = onEdit != null || onShare != null;

    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Container(
          padding: const EdgeInsets.all(DcoLayout.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            border: Border.all(
              color: isActive
                  ? tokens.border.highlight.withValues(alpha: 0.45)
                  : tokens.border.divider,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Photo(path: vehicle.photoLocalPath),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vehicle.source == VehicleSource.shared) ...[
                          SizedBox(width: tokens.space.s2),
                          _Badge(
                            label: s.garageSharedBadge,
                            color: tokens.status.infoFg,
                            background: tokens.status.infoBg,
                          ),
                        ],
                        if (hasMenu) ...[
                          const Spacer(),
                          _VehicleMenu(onEdit: onEdit, onShare: onShare),
                        ],
                      ],
                    ),
                    SizedBox(height: tokens.space.s1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.yearMakeModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(width: tokens.space.s2),
                        Text(
                          vehicle.licensePlate,
                          style: GoogleFonts.ibmPlexMono(
                            color: tokens.text.caption,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.space.s3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mileage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexMono(
                              color: tokens.text.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isActive)
                          _Badge(
                            label: s.active,
                            color: tokens.text.accent,
                            background: tokens.background.navActive,
                          )
                        else if (onSetActive != null)
                          TextButton(
                            onPressed: onSetActive,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.space.s2,
                              ),
                              foregroundColor: tokens.text.link,
                              textStyle: Theme.of(context).textTheme.labelLarge,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(s.vehicleSetActive),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleMenu extends StatelessWidget {
  const _VehicleMenu({required this.onEdit, required this.onShare});

  final VoidCallback? onEdit;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return PopupMenuButton<_VehicleMenuAction>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tokens.background.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.border.divider),
        ),
        child: Icon(Icons.more_horiz, size: 18, color: tokens.icon.inactive),
      ),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _VehicleMenuAction.edit:
            onEdit?.call();
          case _VehicleMenuAction.share:
            onShare?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: _VehicleMenuAction.edit,
            height: 48,
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: tokens.icon.inactive,
                ),
                SizedBox(width: tokens.space.s3),
                Text(s.vehicleEditTooltip),
              ],
            ),
          ),
        if (onShare != null)
          PopupMenuItem(
            value: _VehicleMenuAction.share,
            height: 48,
            child: Row(
              children: [
                Icon(Icons.ios_share, size: 20, color: tokens.icon.inactive),
                SizedBox(width: tokens.space.s3),
                Text(s.vehicleShareTooltip),
              ],
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: SizedBox(
        width: 72,
        height: 72,
        child: path == null
            ? ColoredBox(
                color: tokens.background.input,
                child: Icon(
                  Icons.directions_car_outlined,
                  color: tokens.icon.inactive,
                ),
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: tokens.background.input,
                  child: Icon(
                    Icons.directions_car_outlined,
                    color: tokens.icon.inactive,
                  ),
                ),
              ),
      ),
    );
  }
}
