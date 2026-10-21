import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';
import '../providers.dart';
import '../../features/auth/presentation/session_controller.dart';

class LicenseDeleteButton extends ConsumerStatefulWidget {
  const LicenseDeleteButton({super.key, this.onDeleted});
  final VoidCallback? onDeleted;

  @override
  ConsumerState<LicenseDeleteButton> createState() =>
      _LicenseDeleteButtonState();
}

class _LicenseDeleteButtonState extends ConsumerState<LicenseDeleteButton> {
  bool _busy = false;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete driving license?'),
        content: const Text(
          'Permanently remove your license and its photos from Profile and Documents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    final repository = ref.read(licenseRepositoryProvider);
    final userId = ref.read(sessionControllerProvider).valueOrNull?.user.id;
    try {
      await repository.deleteMyLicense();
      await db
          .into(db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(
              key: 'personal_document_license',
              value: const Value('null'),
            ),
          );
      if (userId != null) controller.clearDrivingLicenseFor(userId);
      if (mounted) widget.onDeleted?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _delete,
    icon: const Icon(Icons.delete_outline),
    label: Text(_busy ? 'Deleting…' : 'Delete driving license'),
  );
}
