import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/units/mileage_unit.dart';
import 'package:dco_mobile/core/units/mileage_format.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;
import 'package:dco_mobile/features/settings/providers.dart';

class CarDetailScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const CarDetailScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends ConsumerState<CarDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicleAsync = ref.watch(vehicleDetailAsyncProvider(widget.vehicleId));
    final lengthUnit = ref.watch(lengthUnitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Detail'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: tokens.icon.active),
            onPressed: () => context.push(AppRoutes.vehicleEdit(widget.vehicleId)),
          ),
        ],
      ),
      body: vehicleAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (detail) {
          if (detail == null) {
            return DcoEmptyState(
              title: 'Vehicle not found',
              body: 'This vehicle could not be loaded.',
            );
          }

          final vehicle = detail;

          return SingleChildScrollView(
            padding: EdgeInsets.all(tokens.space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VehicleIdentitySection(
                  vehicle: vehicle,
                  lengthUnit: lengthUnit,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.space.s4),
                _DocumentsSection(
                  documents: vehicle.documents,
                  tokens: tokens,
                  onAddDocument: () => _navigateToDocuments(),
                ),
                SizedBox(height: tokens.space.s4),
                _AssignedDriversSection(
                  drivers: vehicle.assignedDrivers,
                  tokens: tokens,
                  onManageDrivers: () => _showManageDrivers(vehicle),
                ),
                SizedBox(height: tokens.space.s4),
                _QuickActionsSection(
                  vehicle: vehicle,
                  tokens: tokens,
                  onLogService: () => _navigateToLogService(),
                  onLogFuel: () => _navigateToLogFuel(),
                  onAddDocument: () => _navigateToDocuments(),
                  onManageDrivers: () => _showManageDrivers(vehicle),
                ),
              ],
            )
          );
        },
      ),
    );
  }

  void _navigateToDocuments() {
    context.push('${AppRoutes.dashboard}/documents?vehicle=${widget.vehicleId}');
  }

  void _navigateToLogService() {
    context.push('${AppRoutes.maintenance}/register?vehicle=${widget.vehicleId}');
  }

  void _navigateToLogFuel() {
    context.push('${AppRoutes.fuelLogs}/new?vehicle=${widget.vehicleId}');
  }

  void _showManageDrivers(family_entities.FamilyVehicleDetail vehicle) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radius.lg)),
      ),
      builder: (context) => _ManageDriversSheet(vehicle: vehicle),
    );
  }
}

class _VehicleIdentitySection extends StatelessWidget {
  final family_entities.FamilyVehicleDetail vehicle;
  final MileageUnit lengthUnit;
  final DcoTokens tokens;

  const _VehicleIdentitySection({
    required this.vehicle,
    required this.lengthUnit,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final mileage = MileageFormat.labeled(vehicle.mileage, lengthUnit);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vehicle Identity', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.text.tertiary)),
          SizedBox(height: tokens.space.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ColoredBox(
                    color: tokens.background.input,
                    child: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
                  ),
                ),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.nickname ?? vehicle.name, style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: tokens.space.s1),
                    Text('${vehicle.licensePlate}  •  ${vehicle.year} ${vehicle.make} ${vehicle.model}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary)),
                    if (vehicle.vin != null && vehicle.vin!.isNotEmpty)
                      Text('VIN: ${vehicle.vin}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.tertiary)),
                    SizedBox(height: tokens.space.s2),
                    Text(mileage, style: GoogleFonts.ibmPlexMono(color: tokens.text.primary, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final List<family_entities.FamilyDocument> documents;
  final DcoTokens tokens;
  final VoidCallback onAddDocument;

  const _DocumentsSection({
    required this.documents,
    required this.tokens,
    required this.onAddDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Documents', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: onAddDocument,
              icon: Icon(Icons.add, size: 18, color: tokens.text.accent),
              label: Text('Add', style: TextStyle(color: tokens.text.accent)),
            ),
          ],
        ),
        SizedBox(height: tokens.space.s2),
        if (documents.isEmpty)
          DcoEmptyState(
            title: 'No documents yet',
            body: 'Add registration, insurance, or other documents.',
            actionLabel: 'Add Document',
            onAction: onAddDocument,
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: documents.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.space.s3),
              itemBuilder: (context, index) {
                final doc = documents[index];
                return _DocumentCard(doc: doc, tokens: tokens);
              },
            ),
          ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final family_entities.FamilyDocument doc;
  final DcoTokens tokens;

  const _DocumentCard({required this.doc, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(tokens.space.s3),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.background.input,
              borderRadius: BorderRadius.circular(tokens.radius.sm),
            ),
            child: Icon(Icons.description_outlined, color: tokens.icon.inactive, size: 32),
          ),
          SizedBox(height: tokens.space.s2),
          Text(doc.name, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: tokens.space.s1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.background.input,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(doc.category, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.text.tertiary)),
          ),
        ],
      ),
    );
  }
}

class _AssignedDriversSection extends StatelessWidget {
  final List<family_entities.AssignedDriver> drivers;
  final DcoTokens tokens;
  final VoidCallback onManageDrivers;

  const _AssignedDriversSection({
    required this.drivers,
    required this.tokens,
    required this.onManageDrivers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Assigned Drivers', style: Theme.of(context).textTheme.titleMedium),
            if (drivers.isNotEmpty)
              TextButton.icon(
                onPressed: onManageDrivers,
                icon: Icon(Icons.settings, size: 18, color: tokens.text.accent),
                label: Text('Manage', style: TextStyle(color: tokens.text.accent)),
              ),
          ],
        ),
        SizedBox(height: tokens.space.s2),
        if (drivers.isEmpty)
          DcoEmptyState(
            title: 'No drivers assigned',
            body: 'Add family members as drivers for this vehicle.',
            actionLabel: 'Assign Driver',
            onAction: onManageDrivers,
          )
        else
          Column(
            children: drivers.map((driver) => _DriverTile(driver: driver, tokens: tokens)).toList(),
          ),
      ],
    );
  }
}

class _DriverTile extends StatelessWidget {
  final family_entities.AssignedDriver driver;
  final DcoTokens tokens;

  const _DriverTile({required this.driver, required this.tokens});

  @override
  Widget build(BuildContext context) {
    Color licenseColor;
    IconData licenseIcon;
    String licenseLabel;
    switch (driver.licenseStatus) {
      case 'valid':
        licenseColor = context.tokens.status.successFg;
        licenseIcon = Icons.check_circle;
        licenseLabel = 'Valid';
        break;
      case 'expiring_soon':
        licenseColor = context.tokens.status.warningFg;
        licenseIcon = Icons.schedule;
        licenseLabel = 'Expiring Soon';
        break;
      case 'expired':
        licenseColor = context.tokens.status.dangerFg;
        licenseIcon = Icons.cancel;
        licenseLabel = 'Expired';
        break;
      default:
        licenseColor = context.tokens.text.tertiary;
        licenseIcon = Icons.help;
        licenseLabel = 'No License';
    }

    return Container(
      margin: EdgeInsets.only(bottom: context.tokens.space.s2),
      padding: EdgeInsets.all(context.tokens.space.s3),
      decoration: BoxDecoration(
        color: context.tokens.background.card,
        borderRadius: BorderRadius.circular(context.tokens.radius.md),
        border: Border.all(color: context.tokens.border.defaultColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.tokens.text.accent,
            child: Text(
              driver.displayName.isNotEmpty ? driver.displayName[0].toUpperCase() : '?',
              style: TextStyle(color: context.tokens.text.onAccent, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: context.tokens.space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.displayName, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (driver.permission == 'full' ? context.tokens.status.infoFg : context.tokens.status.successFg).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        driver.permission == 'full' ? 'Full Access' : 'Drive Only',
                        style: TextStyle(
                          color: driver.permission == 'full' ? context.tokens.status.infoFg : context.tokens.status.successFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: licenseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(licenseIcon, size: 12, color: licenseColor),
                          SizedBox(width: 4),
                          Text(licenseLabel, style: TextStyle(color: licenseColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final family_entities.FamilyVehicleDetail vehicle;
  final DcoTokens tokens;
  final VoidCallback onLogService;
  final VoidCallback onLogFuel;
  final VoidCallback onAddDocument;
  final VoidCallback onManageDrivers;

  const _QuickActionsSection({
    required this.vehicle,
    required this.tokens,
    required this.onLogService,
    required this.onLogFuel,
    required this.onAddDocument,
    required this.onManageDrivers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.space.s2),
        Row(
          children: [
            Expanded(
              child: DcoButton(
                label: 'Log Service',
                variant: DcoButtonVariant.secondary,
                onPressed: onLogService,
              ),
            ),
            SizedBox(width: tokens.space.s2),
            Expanded(
              child: DcoButton(
                label: 'Log Fuel',
                onPressed: onLogFuel,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space.s2),
        Row(
          children: [
            Expanded(
              child: DcoButton(
                label: 'Add Document',
                variant: DcoButtonVariant.secondary,
                onPressed: onAddDocument,
              ),
            ),
            SizedBox(width: tokens.space.s2),
            Expanded(
              child: DcoButton(
                label: 'Manage Drivers',
                variant: DcoButtonVariant.tertiary,
                onPressed: onManageDrivers,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManageDriversSheet extends ConsumerStatefulWidget {
  final family_entities.FamilyVehicleDetail vehicle;

  const _ManageDriversSheet({required this.vehicle});

  @override
  ConsumerState<_ManageDriversSheet> createState() => _ManageDriversSheetState();
}

class _ManageDriversSheetState extends ConsumerState<_ManageDriversSheet> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final familyMembersAsync = ref.watch(familyMembersProvider);
    final vehicle = widget.vehicle;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Manage Drivers', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: tokens.text.primary)),
            SizedBox(height: tokens.space.s2),
            Text('Current Drivers', style: Theme.of(context).textTheme.labelLarge),
            SizedBox(height: tokens.space.s2),
            ...vehicle.assignedDrivers.map((driver) => _DriverListTile(
              driver: driver,
              tokens: tokens,
              onRemove: () => _removeDriver(driver),
            )),
            SizedBox(height: tokens.space.s4),
            Text('Add Driver', style: Theme.of(context).textTheme.labelLarge),
            SizedBox(height: tokens.space.s2),
            familyMembersAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (e, _) => Text('Error: $e'),
              data: (members) {
                final available = members.where((m) => !vehicle.assignedDrivers.any((d) => d.userId == m.userId)).toList();
                if (available.isEmpty) {
                  return Text('All family members are already assigned', style: TextStyle(color: tokens.text.tertiary));
                }
                return Column(
                  children: available.map((member) => _AddDriverTile(
                    member: member,
                    tokens: tokens,
                    onAdd: () => _addDriver(member),
                  )).toList(),
                );
              },
            ),
            SizedBox(height: tokens.space.s4),
            DcoButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _removeDriver(family_entities.AssignedDriver driver) async {
  }

  void _addDriver(family_entities.FamilyMember member) async {
  }
}

class _DriverListTile extends StatelessWidget {
  final family_entities.AssignedDriver driver;
  final DcoTokens tokens;
  final VoidCallback onRemove;

  const _DriverListTile({required this.driver, required this.tokens, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.text.accent,
        child: Text(driver.displayName[0].toUpperCase(), style: TextStyle(color: tokens.text.onAccent)),
      ),
      title: Text(driver.displayName),
      subtitle: Text('${driver.permission == 'full' ? 'Full Access' : 'Drive Only'} • License: ${driver.licenseStatus}'),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, color: tokens.status.dangerFg),
        onPressed: onRemove,
      ),
    );
  }
}

class _AddDriverTile extends StatelessWidget {
  final family_entities.FamilyMember member;
  final DcoTokens tokens;
  final VoidCallback onAdd;

  const _AddDriverTile({required this.member, required this.tokens, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.text.accent,
        child: Text(member.displayName?[0].toUpperCase() ?? member.email[0].toUpperCase(), style: TextStyle(color: tokens.text.onAccent)),
      ),
      title: Text(member.displayName ?? member.email),
      subtitle: Text('Role: ${member.role}'),
      trailing: DcoButton(
        label: 'Assign',
        variant: DcoButtonVariant.secondary,
        expanded: false,
        onPressed: onAdd,
      ),
    );
  }
}
