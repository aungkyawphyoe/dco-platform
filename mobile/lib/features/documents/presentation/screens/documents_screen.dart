import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final active = ref.watch(activeVehicleProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(s.documentsTitle)),
      body: DcoEmptyState(
        title: active == null ? s.documentsNoActiveVehicle : s.documentsEmptyTitle,
        body: active == null
            ? s.documentsEmptyBodyNoVehicle
            : s.documentsEmptyBody(active.displayName),
      ),
    );
  }
}
