import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';

class DeleteRecordAction extends StatefulWidget {
  const DeleteRecordAction({super.key, required this.onDelete});
  final Future<void> Function() onDelete;
  @override
  State<DeleteRecordAction> createState() => _DeleteRecordActionState();
}

class _DeleteRecordActionState extends State<DeleteRecordAction> {
  bool _busy = false;
  Future<void> _delete() async {
    final s = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.delete),
        content: Text(s.recordDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
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
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context)!.delete,
    onPressed: _busy ? null : _delete,
    icon: const Icon(Icons.delete_outline),
  );
}
