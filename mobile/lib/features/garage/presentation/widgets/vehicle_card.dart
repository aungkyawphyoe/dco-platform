import 'dart:io';

import 'package:dco_mobile/core/theme/dco_layout.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/garage/domain/entities/vehicle.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum _VehicleMenuAction { edit, share }

/// Minimum interactive height, per `docs/design-system.md` (44×44 targets).
const double _minHit = 44;

/// Garage list card.
///
/// The vehicle photo leads: a full-height image column on the leading edge
/// (a watermark glyph when no photo exists), then the identity stack —
/// name, model, license plate — with the overflow menu pinned to the same
/// right edge as the action below. The odometer and the active-vehicle
/// action close the card. The active vehicle is marked three ways — tinted
/// surface, brass border, gold "Active" chip — so it never relies on color
/// alone.
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
    final hasMenu = onEdit != null || onShare != null;

    return Material(
      color: isActive ? tokens.background.navActive : tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.lg),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.lg),
            border: Border.all(
              color: isActive
                  ? tokens.border.highlight
                  : tokens.border.divider,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LeadingImage(vehicle: vehicle, width: 88),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(DcoLayout.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _minHit,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            vehicle.displayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (vehicle.source ==
                                            VehicleSource.shared) ...[
                                          SizedBox(width: tokens.space.s2),
                                          _SharedBadge(
                                            label: s.garageSharedBadge,
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: tokens.space.s1),
                                    Text(
                                      vehicle.yearMakeModel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: tokens.text.secondary,
                                          ),
                                    ),
                                    SizedBox(height: tokens.space.s1),
                                    Text(
                                      vehicle.licensePlate,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.text.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasMenu) ...[
                                SizedBox(width: tokens.space.s2),
                                _VehicleMenu(onEdit: onEdit, onShare: onShare),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: tokens.space.s3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _Odometer(
                                mileage: vehicle.mileage,
                                unit: lengthUnit,
                              ),
                            ),
                            if (isActive)
                              _ActiveChip(label: _sentenceCase(s.active))
                            else if (onSetActive != null)
                              _SetActiveButton(
                                label: s.vehicleSetActive,
                                onTap: onSetActive!,
                              ),
                          ],
                        ),
                      ],
                    ),
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

/// Full-height vehicle photo on the leading edge, clipped to the card.
/// Without a photo the column stays — a watermark car glyph clipped by the
/// corner keeps the slot feeling designed rather than empty.
class _LeadingImage extends StatelessWidget {
  const _LeadingImage({required this.vehicle, required this.width});

  final Vehicle vehicle;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final path = vehicle.photoLocalPath;
    final hasPhoto = path != null && path.isNotEmpty;

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.background.input,
          border: Border(right: BorderSide(color: tokens.border.divider)),
        ),
        child: hasPhoto
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _HeroPlaceholder(),
              )
            : const _HeroPlaceholder(),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: tokens.space.s1,
              bottom: tokens.space.s1,
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 48,
              color: tokens.icon.inactive,
            ),
          ),
        ),
      ],
    );
  }
}

/// Odometer reading: the number carries the weight, the unit stays quiet.
class _Odometer extends StatelessWidget {
  const _Odometer({required this.mileage, required this.unit});

  final double mileage;
  final MileageUnit unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: MileageFormat.number(mileage, unit),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.text.primary,
            ),
          ),
          TextSpan(
            text: ' ${unit.label}',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: tokens.text.secondary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Solid gold status chip on the active vehicle — the one loud element in
/// the garage. Not interactive: the card itself opens the vehicle.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: _minHit,
      padding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.button.primary.background,
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: tokens.icon.onAccent),
          SizedBox(width: tokens.space.s1),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.button.primary.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline pill that switches the active vehicle. Same footprint as the
/// active chip so the right edge of the card stays aligned in both states.
class _SetActiveButton extends StatelessWidget {
  const _SetActiveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.full),
        child: Container(
          height: _minHit,
          padding: EdgeInsets.symmetric(horizontal: tokens.space.s4),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border.defaultColor),
            borderRadius: BorderRadius.circular(tokens.radius.full),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: tokens.text.link),
            ),
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
        width: _minHit,
        height: _minHit,
        decoration: BoxDecoration(
          color: tokens.background.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.border.divider),
        ),
        child: Icon(Icons.more_horiz, size: 18, color: tokens.icon.inactive),
      ),
      constraints: const BoxConstraints(
        minWidth: _minHit,
        minHeight: _minHit,
      ),
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

class _SharedBadge extends StatelessWidget {
  const _SharedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.s2,
        vertical: tokens.space.s1,
      ),
      decoration: BoxDecoration(
        color: tokens.status.infoBg,
        borderRadius: BorderRadius.circular(tokens.radius.full),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: tokens.status.infoFg),
      ),
    );
  }
}

/// `s.active` ships lowercase ("active"); status chips read as a word.
/// No-op for scripts without case (e.g. Myanmar).
String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
