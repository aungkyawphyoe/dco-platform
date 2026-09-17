import 'dart:io';

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.isActive,
    required this.onOpen,
    this.lengthUnit = MileageUnit.km,
    this.onSetActive,
    this.onEdit,
    this.isFamily = false,
    this.onDelete,
  });

  final Vehicle vehicle;
  final bool isActive;
  final VoidCallback onOpen;
  final MileageUnit lengthUnit;
  final VoidCallback? onSetActive;
  final VoidCallback? onEdit;
  final bool isFamily;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        boxShadow: tokens.shadows.card,
        border: isActive
            ? Border(left: BorderSide(color: tokens.text.accent, width: 3))
            : null,
      ),
      child: Material(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(tokens.radius.lg),
          child: Padding(
            padding: EdgeInsets.all(tokens.space.s4),
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
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    vehicle.displayName,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isFamily || vehicle.source == VehicleSource.family) ...[
                                  SizedBox(width: tokens.space.s2),
                                  _Badge(
                                    label: s.garageFamilyBadge,
                                    color: tokens.text.accent,
                                    background: tokens.background.card,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isActive)
                            _Badge(label: s.active, color: tokens.status.infoFg, background: tokens.status.infoBg)
                          else if (onSetActive != null)
                            TextButton(
                              onPressed: onSetActive,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: EdgeInsets.symmetric(horizontal: tokens.space.s2),
                              ),
                              child: Text(s.vehicleSetActive, style: TextStyle(color: tokens.text.link, fontSize: 12)),
                            ),
                          if (onEdit != null)
                            IconButton(
                              tooltip: s.vehicleEditTooltip,
                              onPressed: onEdit,
                              icon: Icon(Icons.edit_outlined, size: 20, color: tokens.icon.inactive),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              padding: EdgeInsets.zero,
                            ),
                          if (onDelete != null)
                            IconButton(
                              tooltip: s.vehicleRemoveTooltip,
                              onPressed: onDelete,
                              icon: Icon(Icons.delete_outline, size: 20, color: tokens.status.dangerFg),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      Text(
                        '${vehicle.yearMakeModel}  ${vehicle.licensePlate}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.secondary),
                      ),
                      SizedBox(height: tokens.space.s2),
                      Text(
                        mileage,
                        style: GoogleFonts.ibmPlexMono(
                          color: tokens.text.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
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
      borderRadius: BorderRadius.circular(tokens.radius.sm),
      child: SizedBox(
        width: 72,
        height: 72,
        child: path == null
            ? ColoredBox(
                color: tokens.background.input,
                child: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: tokens.background.input,
                  child: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
                ),
              ),
      ),
    );
  }
}
