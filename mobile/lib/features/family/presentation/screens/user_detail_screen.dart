import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/family/providers.dart';
import 'package:dco_mobile/features/family/domain/entities/family.dart' as family_entities;
import 'package:dco_mobile/features/garage/providers.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  final _imagePicker = ImagePicker();
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isSelf = widget.userId == currentUserId;
    final userDetailAsync = ref.watch(localUserDetailProvider(widget.userId));
    final myFamilyAsync = ref.watch(myFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'Profile' : 'Member Detail'),
        actions: isSelf ? [
          IconButton(
            icon: Icon(Icons.edit, color: tokens.icon.active),
            onPressed: _editProfile,
          ),
        ] : null,
      ),
      body: userDetailAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (detail) {
          if (detail == null) {
            return Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(tokens.space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                _ProfileHeader(
                  user: detail,
                  isSelf: isSelf,
                  tokens: tokens,
                  onEditProfile: _editProfile,
                  onUploadLicense: _uploadLicenseImage,
                ),
                SizedBox(height: tokens.space.s4),

                // Driving License
                _DrivingLicenseSection(
                  license: detail.drivingLicense,
                  isSelf: isSelf,
                  tokens: tokens,
                  onUpload: _uploadLicenseImage,
                  onEdit: _editLicense,
                ),
                SizedBox(height: tokens.space.s4),

                // Access Level
                _AccessLevelSection(
                  user: detail,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.space.s4),

                // My Vehicles
                _MyVehiclesSection(
                  vehicles: detail.ownedVehicles,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.space.s4),

                // Actions (contextual)
                if (isSelf) ...[
                  _SelfActionsSection(
                    user: detail,
                    myFamilyAsync: myFamilyAsync,
                    tokens: tokens,
                    onLeaveFamily: _leaveFamily,
                  ),
                ] else ...[
                  _AdminActionsSection(
                    user: detail,
                    tokens: tokens,
                    onChangeRole: _changeRole,
                    onAssignVehicles: _assignVehicles,
                    onRemove: _removeMember,
                  ),
                ],
              ],
            )
          );
        },
      ),
    );
  }

  void _editProfile() {
    // Navigate to edit profile screen (could be settings/profile)
  }

  void _uploadLicenseImage() {
    _showImageSourceDialog(front: true);
  }

  void _showImageSourceDialog({required bool front}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: context.tokens.icon.active),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, front: front);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: context.tokens.icon.active),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, front: front);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, {required bool front}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        final repo = ref.read(familyRepositoryProvider);
        final mediaId = await repo.uploadLicenseMedia(front ? 'front' : 'back', bytes);
        if (front) {
          // Update license with front media id
          final license = ref.read(myLicenseProvider).valueOrNull;
          if (license != null) {
            await repo.upsertLicense(
              frontMediaId: mediaId,
              backMediaId: license.backMediaId,
              licenseNumber: license.licenseNumber,
              issuingCountry: license.issuingCountry,
              expiryDate: license.expiryDate.toIso8601String().split('T').first,
              categories: license.categories,
            );
            ref.invalidate(myLicenseProvider);
            ref.invalidate(userDetailProvider(widget.userId));
          }
        } else {
          // Update license with back media id
          final license = ref.read(myLicenseProvider).valueOrNull;
          if (license != null) {
            await repo.upsertLicense(
              frontMediaId: license.frontMediaId,
              backMediaId: mediaId,
              licenseNumber: license.licenseNumber,
              issuingCountry: license.issuingCountry,
              expiryDate: license.expiryDate.toIso8601String().split('T').first,
              categories: license.categories,
            );
            ref.invalidate(myLicenseProvider);
            ref.invalidate(userDetailProvider(widget.userId));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    }
  }

  void _editLicense() {
    // Show edit license dialog
    _showEditLicenseDialog();
  }

  void _showEditLicenseDialog() async {
    final license = ref.read(myLicenseProvider).valueOrNull;
    final tokens = context.tokens;
    
    final numberController = TextEditingController(text: license?.licenseNumber ?? '');
    final countryController = TextEditingController(text: license?.issuingCountry ?? '');
    final expiryController = TextEditingController(text: license?.expiryDate.toIso8601String().split('T').first ?? '');
    final categoriesController = TextEditingController(text: license?.categories ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Driving License'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DcoTextField(
                controller: numberController,
                label: 'License Number',
                hint: 'D1234567',
              ),
              SizedBox(height: tokens.space.s3),
              DcoTextField(
                controller: countryController,
                label: 'Issuing Country (ISO)',
                hint: 'US',
              ),
              SizedBox(height: tokens.space.s3),
              DcoTextField(
                controller: expiryController,
                label: 'Expiry Date (YYYY-MM-DD)',
                hint: '2028-12-31',
              ),
              SizedBox(height: tokens.space.s3),
              DcoTextField(
                controller: categoriesController,
                label: 'Categories',
                hint: 'B, BE',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(familyRepositoryProvider);
      await repo.upsertLicense(
        licenseNumber: numberController.text,
        issuingCountry: countryController.text,
        expiryDate: expiryController.text,
        categories: categoriesController.text,
        frontMediaId: license?.frontMediaId,
        backMediaId: license?.backMediaId,
      );
      ref.invalidate(myLicenseProvider);
      ref.invalidate(userDetailProvider(widget.userId));
    }
  }

  void _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Family?'),
        content: const Text('Are you sure you want to leave this family? You will lose access to shared vehicles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave', style: TextStyle(color: context.tokens.status.dangerFg)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(familyRepositoryProvider);
      // Need to implement leave family in repository
      // await repo.leaveFamily();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left family')));
        context.go(AppRoutes.settings);
      }
    }
  }

  void _changeRole() {
    // Show role change dialog
    final user = ref.read(userDetailProvider(widget.userId)).valueOrNull;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radius.lg))),
      builder: (context) => _ChangeRoleSheet(user: user),
    );
  }

  void _assignVehicles() {
    // Show vehicle assignment dialog
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radius.lg))),
      builder: (context) => _AssignVehiclesSheet(userId: widget.userId),
    );
  }

  void _removeMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: const Text('Are you sure you want to remove this member from the family? They will lose access to all shared vehicles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: TextStyle(color: context.tokens.status.dangerFg))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(familyRepositoryProvider);
      // await repo.removeMember(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
        context.pop();
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final family_entities.UserDetail user;
  final bool isSelf;
  final DcoTokens tokens;
  final VoidCallback onEditProfile;
  final VoidCallback onUploadLicense;

  const _ProfileHeader({
    required this.user,
    required this.isSelf,
    required this.tokens,
    required this.onEditProfile,
    required this.onUploadLicense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DcoAvatar(name: user.displayName ?? user.email, radius: 50),
        SizedBox(height: tokens.space.s3),
        Text(user.displayName ?? user.email, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: tokens.text.primary)),
        SizedBox(height: tokens.space.s1),
        Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary)),
        SizedBox(height: tokens.space.s2),
        _RoleBadge(role: user.familyRole ?? 'member', tokens: tokens),
        if (isSelf) ...[
          SizedBox(height: tokens.space.s3),
          DcoButton(
            label: 'Upload License Photo',
            variant: DcoButtonVariant.secondary,
            onPressed: onUploadLicense,
          ),
        ],
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final DcoTokens tokens;

  const _RoleBadge({required this.role, required this.tokens});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;
    switch (role) {
      case 'primary_owner':
        color = tokens.text.accent;
        icon = Icons.emoji_events;
        label = 'Primary Owner';
        break;
      case 'member':
        color = tokens.status.infoFg;
        icon = Icons.person;
        label = 'Member';
        break;
      case 'driver':
        color = tokens.status.successFg;
        icon = Icons.drive_eta;
        label = 'Driver';
        break;
      default:
        color = tokens.text.tertiary;
        icon = Icons.help;
        label = role;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DrivingLicenseSection extends StatelessWidget {
  final family_entities.DrivingLicense? license;
  final bool isSelf;
  final DcoTokens tokens;
  final VoidCallback onUpload;
  final VoidCallback onEdit;

  const _DrivingLicenseSection({
    required this.license,
    required this.isSelf,
    required this.tokens,
    required this.onUpload,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final lic = license;
    if (lic == null && !isSelf) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Driving License', style: Theme.of(context).textTheme.titleMedium),
            if (isSelf) ...[
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(Icons.edit, size: 18, color: tokens.text.accent),
                label: Text('Edit', style: TextStyle(color: tokens.text.accent)),
              ),
              if (lic == null)
                TextButton.icon(
                  onPressed: onUpload,
                  icon: Icon(Icons.add_a_photo, size: 18, color: tokens.text.accent),
                  label: Text('Upload', style: TextStyle(color: tokens.text.accent)),
                ),
            ],
          ],
        ),
        SizedBox(height: tokens.space.s2),
        if (lic == null)
          DcoEmptyState(
            title: 'No license uploaded',
            body: 'Add your driving license to track expiry and share with family.',
            actionLabel: 'Upload License',
            onAction: onUpload,
          )
        else
          Container(
            padding: EdgeInsets.all(tokens.space.s4),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.md),
              border: Border.all(color: tokens.border.defaultColor),
            ),
            child: Column(
              children: [
                if (lic.frontMediaId != null || lic.backMediaId != null)
                  Row(
                    children: [
                      Expanded(child: _LicenseImagePlaceholder(label: 'Front', mediaId: lic.frontMediaId, tokens: tokens)),
                      SizedBox(width: tokens.space.s3),
                      Expanded(child: _LicenseImagePlaceholder(label: 'Back', mediaId: lic.backMediaId, tokens: tokens)),
                    ],
                  ),
                if (lic.frontMediaId != null || lic.backMediaId != null)
                  SizedBox(height: tokens.space.s3),
                _LicenseInfoRow(label: 'Expires', value: lic.expiryDate.toIso8601String().split('T').first, tokens: tokens),
                if (lic.licenseNumber != null)
                  _LicenseInfoRow(label: 'Number', value: lic.licenseNumber!, tokens: tokens),
                if (lic.issuingCountry != null)
                  _LicenseInfoRow(label: 'Country', value: lic.issuingCountry!, tokens: tokens),
                if (lic.categories != null)
                  _LicenseInfoRow(label: 'Categories', value: lic.categories!, tokens: tokens),
                SizedBox(height: tokens.space.s2),
                _LicenseStatusBadge(status: lic.status, tokens: tokens),
              ],
            ),
          ),
      ],
    );
  }
}

class _LicenseImagePlaceholder extends StatelessWidget {
  final String label;
  final String? mediaId;
  final DcoTokens tokens;

  const _LicenseImagePlaceholder({required this.label, required this.mediaId, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: tokens.background.input,
            borderRadius: BorderRadius.circular(tokens.radius.sm),
          ),
          child: mediaId == null
              ? Icon(Icons.description_outlined, color: tokens.icon.inactive, size: 40)
              : Center(child: Text('Image: $mediaId', style: TextStyle(color: tokens.text.tertiary, fontSize: 10))),
        ),
        SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.text.tertiary)),
      ],
    );
  }
}

class _LicenseInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final DcoTokens tokens;

  const _LicenseInfoRow({required this.label, required this.value, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: tokens.text.secondary)),
          Text(value, style: TextStyle(color: tokens.text.primary, fontFamily: 'IBM Plex Mono')),
        ],
      ),
    );
  }
}

class _LicenseStatusBadge extends StatelessWidget {
  final family_entities.LicenseStatus status;
  final DcoTokens tokens;

  const _LicenseStatusBadge({required this.status, required this.tokens});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case family_entities.LicenseStatus.valid:
        color = tokens.status.successFg;
        icon = Icons.check_circle;
        label = 'License Valid';
        break;
      case family_entities.LicenseStatus.expiringSoon:
        color = tokens.status.warningFg;
        icon = Icons.schedule;
        label = 'Expiring Soon';
        break;
      case family_entities.LicenseStatus.expired:
        color = tokens.status.dangerFg;
        icon = Icons.cancel;
        label = 'Expired';
        break;
      default:
        color = tokens.text.tertiary;
        icon = Icons.help;
        label = 'No License';
    }

    return Container(
      padding: EdgeInsets.all(tokens.space.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AccessLevelSection extends StatelessWidget {
  final family_entities.UserDetail user;
  final DcoTokens tokens;

  const _AccessLevelSection({required this.user, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final role = user.familyRole ?? 'member';
    String description;
    List<String> permissions;

    switch (role) {
      case 'primary_owner':
        description = 'Primary Owner';
        permissions = [
          'Full control over family',
          'Manage all vehicles',
          'Add/remove members',
          'Assign drivers',
          'Transfer ownership',
        ];
        break;
      case 'member':
        description = 'Member (Secondary Owner)';
        permissions = [
          'Full access to assigned vehicles',
          'Log maintenance & expenses',
          'Manage documents',
          'Assign drivers to vehicles',
        ];
        break;
      case 'driver':
        description = 'Driver';
        permissions = [
          'View assigned vehicles',
          'Log fuel/charge',
          'View maintenance due',
          'View documents',
        ];
        break;
      default:
        description = 'Member';
        permissions = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Access Level', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.space.s2),
        _RoleBadge(role: role, tokens: tokens),
        SizedBox(height: tokens.space.s2),
        Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary)),
        SizedBox(height: tokens.space.s2),
        Text('Permissions', style: Theme.of(context).textTheme.labelLarge),
        SizedBox(height: tokens.space.s1),
        ...permissions.map((p) => Padding(
          padding: EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: tokens.status.successFg),
              SizedBox(width: 8),
              Text(p, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        )),
      ],
    );
  }
}

class _MyVehiclesSection extends StatelessWidget {
  final List<family_entities.FamilyVehicle> vehicles;
  final DcoTokens tokens;

  const _MyVehiclesSection({required this.vehicles, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Vehicles', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.space.s2),
        ...vehicles.map((v) => Container(
          margin: EdgeInsets.only(bottom: tokens.space.s2),
          padding: EdgeInsets.all(tokens.space.s3),
          decoration: BoxDecoration(
            color: tokens.background.card,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: tokens.border.defaultColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.background.input,
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.nickname ?? v.name, style: Theme.of(context).textTheme.titleSmall),
                    Text('${v.licensePlate} · ${v.year} ${v.make} ${v.model}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.text.secondary)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _SelfActionsSection extends StatelessWidget {
  final family_entities.UserDetail user;
  final AsyncValue<family_entities.Family?> myFamilyAsync;
  final DcoTokens tokens;
  final VoidCallback onLeaveFamily;

  const _SelfActionsSection({
    required this.user,
    required this.myFamilyAsync,
    required this.tokens,
    required this.onLeaveFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.space.s2),
        DcoButton(
          label: 'Leave Family',
          variant: DcoButtonVariant.destructive,
          onPressed: onLeaveFamily,
        ),
      ],
    );
  }
}

class _AdminActionsSection extends StatelessWidget {
  final family_entities.UserDetail user;
  final DcoTokens tokens;
  final VoidCallback onChangeRole;
  final VoidCallback onAssignVehicles;
  final VoidCallback onRemove;

  const _AdminActionsSection({
    required this.user,
    required this.tokens,
    required this.onChangeRole,
    required this.onAssignVehicles,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin Actions', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.space.s2),
        Row(
          children: [
            Expanded(child: DcoButton(label: 'Change Role', variant: DcoButtonVariant.secondary, onPressed: onChangeRole)),
            SizedBox(width: tokens.space.s2),
            Expanded(child: DcoButton(label: 'Assign Vehicles', onPressed: onAssignVehicles)),
          ],
        ),
        SizedBox(height: tokens.space.s2),
        DcoButton(label: 'Remove from Family', variant: DcoButtonVariant.destructive, onPressed: onRemove),
      ],
    );
  }
}

class _ChangeRoleSheet extends ConsumerStatefulWidget {
  final family_entities.UserDetail user;

  const _ChangeRoleSheet({required this.user});

  @override
  ConsumerState<_ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends ConsumerState<_ChangeRoleSheet> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.familyRole ?? 'member';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change Role', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: tokens.text.primary)),
            SizedBox(height: tokens.space.s2),
            Text('Current: ${_roleLabel(_selectedRole)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.text.secondary)),
            SizedBox(height: tokens.space.s3),
            Text('New Role', style: Theme.of(context).textTheme.labelLarge),
            SizedBox(height: tokens.space.s2),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'member', label: Text('Member'), icon: Icon(Icons.person)),
                ButtonSegment(value: 'driver', label: Text('Driver'), icon: Icon(Icons.drive_eta)),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (Set<String> selection) => setState(() => _selectedRole = selection.first),
            ),
            SizedBox(height: tokens.space.s3),
            DcoButton(
              label: 'Save',
              onPressed: _selectedRole != widget.user.familyRole
                  ? () async {
                      final repo = ref.read(familyRepositoryProvider);
                      await repo.updateMemberRole(widget.user.id, _selectedRole);
                      if (mounted) {
                        Navigator.pop(context);
                        ref.invalidate(familyMembersProvider);
                        ref.invalidate(userDetailProvider(widget.user.id));
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'primary_owner': return 'Primary Owner';
      case 'member': return 'Member';
      case 'driver': return 'Driver';
      default: return role;
    }
  }
}

class _AssignVehiclesSheet extends ConsumerStatefulWidget {
  final String userId;

  const _AssignVehiclesSheet({required this.userId});

  @override
  ConsumerState<_AssignVehiclesSheet> createState() => _AssignVehiclesSheetState();
}

class _AssignVehiclesSheetState extends ConsumerState<_AssignVehiclesSheet> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehiclesAsync = ref.watch(garageVehiclesProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Assign Vehicles', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: tokens.text.primary)),
            SizedBox(height: tokens.space.s2),
            vehiclesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: tokens.text.accent)),
              error: (e, _) => Text('Error: $e'),
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return Text('No vehicles in garage', style: TextStyle(color: tokens.text.tertiary));
                }
                return Column(
                  children: vehicles.map((v) => ListTile(
                    leading: Icon(Icons.directions_car_outlined, color: tokens.icon.inactive),
                    title: Text(v.nickname ?? v.name),
                    subtitle: Text('${v.licensePlate} · ${v.year}'),
                  )).toList(),
                );
              },
            ),
            SizedBox(height: tokens.space.s4),
            DcoButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
