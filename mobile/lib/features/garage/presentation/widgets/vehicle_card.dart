import 'dart:io';

import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.isActive,
    required this.onOpen,
    this.onSetActive,
  });

  final Vehicle vehicle;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback? onSetActive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mileage = NumberFormat('#,###').format(vehicle.mileage.round());
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(tokens.radius.md),
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
                          child: Text(
                            vehicle.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (isActive)
                          _Badge(label: 'active', color: tokens.status.infoFg, background: tokens.status.infoBg)
                        else if (onSetActive != null)
                          TextButton(
                            onPressed: onSetActive,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: EdgeInsets.symmetric(horizontal: tokens.space.s2),
                            ),
                            child: Text('Set active', style: TextStyle(color: tokens.text.link, fontSize: 12)),
                          ),
                      ],
                    ),
                    Text(
                      '${vehicle.yearMakeModel}  ${vehicle.licensePlate}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.secondary),
                    ),
                    SizedBox(height: tokens.space.s2),
                    Text(
                      '$mileage ${vehicle.mileageUnit.label}',
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
            : Image.file(File(path!), fit: BoxFit.cover),
      ),
    );
  }
}
