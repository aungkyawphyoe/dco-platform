import 'dart:io';

import 'package:dco_mobile/core/entities/driving_license.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/features/profile/presentation/widgets/license_photo_card.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Profile edit form: name, contact phone, address, profile photo, driving
/// license (number, expiry, photos), and account deletion.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _licenseNumberController;
  late final TextEditingController _expiryDateController;
  bool _saving = false;
  bool _licenseSaving = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).valueOrNull?.user;
    final license = user?.drivingLicense;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.contactPhone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _licenseNumberController = TextEditingController(
      text: license?.licenseNumber ?? '',
    );
    _expiryDateController = TextEditingController(
      text: license != null
          ? license.expiryDate.toIso8601String().split('T').first
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _licenseNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      setState(() => _photoPath = image.path);
      try {
        final repo = ref.read(profileRepositoryProvider);
        await repo.uploadPhoto(image.path);
        if (mounted) {
          final session = await ref.read(profileRepositoryProvider).get();
          ref.read(sessionControllerProvider.notifier).updateUser(session);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final updated = await repo.update(
        displayName: _nameController.text.trim(),
        contactPhone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      ref.read(sessionControllerProvider.notifier).updateUser(updated);
      if (mounted) {
        final s = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.profileSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _captureLicensePhoto(String side) async {
    final capturedPath = await GoRouter.of(
      context,
    ).push<String>(AppRoutes.licenseCapture, extra: side);
    if (capturedPath == null || capturedPath.isEmpty) return;

    try {
      final bytes = await File(capturedPath).readAsBytes();
      final repo = ref.read(licenseRepositoryProvider);
      final mediaId = await repo.uploadLicensePhoto(side, bytes);

      final user = ref.read(sessionControllerProvider).valueOrNull?.user;
      final license = user?.drivingLicense;

      final String frontMediaId =
          side == 'front' ? mediaId : license?.frontMediaId ?? '';
      final String backMediaId =
          side == 'back' ? mediaId : license?.backMediaId ?? '';

      await repo.upsertLicense(
        licenseNumber: _licenseNumberController.text.trim().isEmpty
            ? null
            : _licenseNumberController.text.trim(),
        expiryDate: _expiryDateController.text.trim(),
        frontMediaId: frontMediaId,
        backMediaId: backMediaId,
      );

      if (mounted) {
        await _refreshSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              side == 'front'
                  ? AppLocalizations.of(context)!.profileLicenseFrontSaved
                  : AppLocalizations.of(context)!.profileLicenseBackSaved,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveLicense() async {
    if (_licenseNumberController.text.trim().isEmpty ||
        _expiryDateController.text.trim().isEmpty) {
      return;
    }
    setState(() => _licenseSaving = true);
    try {
      final repo = ref.read(licenseRepositoryProvider);
      final user = ref.read(sessionControllerProvider).valueOrNull?.user;
      final license = user?.drivingLicense;

      await repo.upsertLicense(
        licenseNumber: _licenseNumberController.text.trim(),
        expiryDate: _expiryDateController.text.trim(),
        frontMediaId: license?.frontMediaId,
        backMediaId: license?.backMediaId,
      );

      if (mounted) {
        await _refreshSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileLicenseSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _licenseSaving = false);
    }
  }

  Future<void> _refreshSession() async {
    final user = await ref.read(profileRepositoryProvider).get();
    DrivingLicense? license;
    try {
      license = await ref.read(licenseRepositoryProvider).getMyLicense();
    } catch (_) {}
    ref.read(sessionControllerProvider.notifier).updateUser(
      user.copyWith(drivingLicense: license),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initialDate = _expiryDateController.text.isNotEmpty
        ? DateTime.tryParse(_expiryDateController.text) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) {
      _expiryDateController.text =
          picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _deleteAccount() async {
    final s = AppLocalizations.of(context)!;
    final user = ref.read(sessionControllerProvider).valueOrNull?.user;
    if (user == null) return;

    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.profileDeleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.profileDeleteAccountBody),
            const SizedBox(height: 16),
            DcoTextField(
              label: s.profileDeleteAccountPassword,
              controller: passwordController,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              s.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || passwordController.text.isEmpty) return;

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.deleteAccount(password: passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.profileDeleteAccountSuccess)));
        await ref.read(sessionControllerProvider.notifier).signOut();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('transfer_required')
            ? s.profileDeleteAccountBlocked
            : '$e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final user = ref.watch(sessionControllerProvider).valueOrNull?.user;
    final license = user?.drivingLicense;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profileTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.text.accent,
                    ),
                  )
                : Text(s.save, style: TextStyle(color: tokens.text.accent)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(tokens.space.s5),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  if (_photoPath != null)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: FileImage(File(_photoPath!)),
                    )
                  else
                    DcoAvatar(name: user?.displayName ?? user?.email ?? '?', radius: 50),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tokens.background.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.border.defaultColor),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: tokens.icon.inactive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space.s2),
          Center(
            child: Text(
              s.profilePhotoTapToChange,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
          ),
          SizedBox(height: tokens.space.s5),
          DcoTextField(
            label: s.profileName,
            controller: _nameController,
            hint: s.profileNameHint,
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            label: s.profileContactPhone,
            controller: _phoneController,
            hint: s.profileContactPhoneHint,
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            label: s.profileAddress,
            controller: _addressController,
            hint: s.profileAddressHint,
            maxLines: 2,
          ),
          SizedBox(height: tokens.space.s3),
          Container(
            padding: EdgeInsets.all(tokens.space.s3),
            decoration: BoxDecoration(
              color: tokens.background.card,
              borderRadius: BorderRadius.circular(tokens.radius.lg),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  color: tokens.icon.inactive,
                  size: 20,
                ),
                SizedBox(width: tokens.space.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        user?.emailVerified == true
                            ? s.profileEmailVerified
                            : s.profileEmailNotVerified,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: user?.emailVerified == true
                              ? tokens.status.successFg
                              : tokens.text.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.space.s3),
          if (user?.createdAt != null)
            Text(
              '${s.profileMemberSince} ${DateFormat.yMMMd().format(DateTime.parse(user!.createdAt!))}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.text.caption),
            ),
          SizedBox(height: tokens.space.s5),
          _DrivingLicenseSection(
            license: license,
            tokens: tokens,
            numberController: _licenseNumberController,
            expiryController: _expiryDateController,
            onCapturePhoto: _captureLicensePhoto,
            onPickExpiry: _pickExpiryDate,
            onSaveLicense: _saveLicense,
            saving: _licenseSaving,
          ),
          SizedBox(height: tokens.space.s7),
          DcoButton(
            label: s.profileDeleteAccount,
            variant: DcoButtonVariant.destructive,
            onPressed: _deleteAccount,
          ),
          SizedBox(height: tokens.space.s5),
        ],
      ),
    );
  }
}

class _DrivingLicenseSection extends StatelessWidget {
  const _DrivingLicenseSection({
    required this.license,
    required this.tokens,
    required this.numberController,
    required this.expiryController,
    required this.onCapturePhoto,
    required this.onPickExpiry,
    required this.onSaveLicense,
    required this.saving,
  });

  final DrivingLicense? license;
  final DcoTokens tokens;
  final TextEditingController numberController;
  final TextEditingController expiryController;
  final LicensePhotoCaptureCallback onCapturePhoto;
  final VoidCallback onPickExpiry;
  final VoidCallback onSaveLicense;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.border.defaultColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.profileLicenseSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.space.s3),
          LicensePhotoCard(
            frontMediaId: license?.frontMediaId,
            backMediaId: license?.backMediaId,
            onCapture: onCapturePhoto,
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            label: s.profileLicenseNumber,
            controller: numberController,
            hint: s.profileLicenseNumberHint,
          ),
          SizedBox(height: tokens.space.s3),
          DcoTextField(
            label: s.profileLicenseExpiry,
            controller: expiryController,
            hint: s.profileLicenseExpiryHint,
            readOnly: true,
            onTap: onPickExpiry,
          ),
          if (license != null) ...[
            SizedBox(height: tokens.space.s3),
            _LicenseStatusBadge(
              status: license!.status,
              tokens: tokens,
            ),
          ],
          SizedBox(height: license != null ? tokens.space.s4 : tokens.space.s3),
          DcoButton(
            label: s.profileLicenseSave,
            loading: saving,
            onPressed: onSaveLicense,
          ),
        ],
      ),
    );
  }
}

class _LicenseStatusBadge extends StatelessWidget {
  const _LicenseStatusBadge({required this.status, required this.tokens});

  final LicenseStatus status;
  final DcoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case LicenseStatus.valid:
        color = tokens.status.successFg;
        icon = Icons.check_circle;
        label = s.userDetailLicenseValid;
        break;
      case LicenseStatus.expiringSoon:
        color = tokens.status.warningFg;
        icon = Icons.schedule;
        label = s.userDetailLicenseExpiringSoon;
        break;
      case LicenseStatus.expired:
        color = tokens.status.dangerFg;
        icon = Icons.cancel;
        label = s.userDetailLicenseExpired;
        break;
      case LicenseStatus.none:
        color = tokens.text.tertiary;
        icon = Icons.help;
        label = s.userDetailLicenseNone;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.space.s3, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
