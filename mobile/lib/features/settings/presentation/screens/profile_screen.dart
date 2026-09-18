import 'dart:io';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_avatar.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/auth/presentation/session_controller.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _saving = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).valueOrNull?.user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.contactPhone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
                    DcoAvatar(name: user?.email ?? '?', radius: 50),
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
