import 'package:dco_mobile/core/widgets/license_delete_button.dart';
import 'dart:io';
import 'package:dco_mobile/features/profile/presentation/widgets/license_flip_card.dart';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/documents/providers.dart';
import 'package:dco_mobile/features/garage/access_provider.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dco_mobile/core/router/routes.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final documents = ref.watch(vehicleDocumentsProvider);
    final license = ref.watch(personalDocumentLicenseProvider).valueOrNull;
    final usage = ref.watch(documentStorageProvider).valueOrNull;
    final access = ref.watch(vehicleAccessProvider(vehicle));

    final canCreate =
        access.isOwner ||
        (ref.watch(driverOrganizationIdProvider) != null && access.canCreate);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.documentsTitle),
        actions: [
          IconButton(
            tooltip: s.documentsAddTooltip,
            onPressed: !canCreate
                ? null
                : () => context.push(AppRoutes.documentNew),
            icon: Icon(
              Icons.add,
              color: !canCreate ? tokens.icon.inactive : tokens.icon.active,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (usage != null)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(
                'Storage: ${((usage['used_bytes'] as num) / (1024 * 1024)).toStringAsFixed(1)} / ${((usage['limit_bytes'] as num) / (1024 * 1024)).toStringAsFixed(0)} MB',
              ),
              subtitle:
                  (usage['used_bytes'] as num) >= (usage['limit_bytes'] as num)
                  ? Text(
                      usage['scope'] == 'organization'
                          ? 'Organization storage is full. Contact your fleet admin.'
                          : 'Storage is full. Delete unneeded documents to free space.',
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh storage',
                onPressed: () => ref.invalidate(documentStorageProvider),
              ),
            ),
          if (usage != null &&
              usage['scope'] == 'personal' &&
              (usage['used_bytes'] as num) >= (usage['limit_bytes'] as num))
            TextButton(
              onPressed: () => context.push(AppRoutes.pricing),
              child: Text(AppLocalizations.of(context)!.pricingViewPlans),
            ),
          if (license?.frontMediaId != null)
            ExpansionTile(
              title: const Text('Personal Documents'),
              subtitle: const Text('Driving license · Private'),
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.space.s4),
                  child: LicenseFlipCard(
                    frontMediaId: license!.frontMediaId,
                    backMediaId: license.backMediaId,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await context.push(AppRoutes.profileEdit);
                    ref.invalidate(personalDocumentLicenseProvider);
                  },
                  child: const Text('Manage driving license'),
                ),
                const LicenseDeleteButton(),
              ],
            ),
          Expanded(
            child: vehicle == null
                ? Center(
                    child: DcoEmptyState(
                      title: s.documentsNoActiveVehicle,
                      body: s.documentsNoActiveVehicleBody,
                    ),
                  )
                : documents.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: tokens.text.accent,
                      ),
                    ),
                    error: (error, _) => DcoEmptyState(
                      title: s.documentsLoadError,
                      body: '$error',
                    ),
                    data: (items) => items.isEmpty
                        ? Center(
                            child: DcoEmptyState(
                              title: s.documentsEmptyTitle,
                              body: s.documentsEmptyBody(vehicle.displayName),
                              actionLabel: canCreate
                                  ? s.documentsAddDocument
                                  : null,
                              onAction: canCreate
                                  ? () => context.push(AppRoutes.documentNew)
                                  : null,
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              tokens.space.s4,
                              tokens.space.s2,
                              tokens.space.s4,
                              tokens.space.s5,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final doc = items[index];
                              final locked =
                                  ref
                                      .watch(
                                        recordAdminLockProvider(
                                          'document:${doc.id}',
                                        ),
                                      )
                                      .valueOrNull ??
                                  (ref.watch(driverOrganizationIdProvider) !=
                                      null);
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: tokens.space.s3,
                                ),
                                child: _DocumentTile(
                                  document: doc,
                                  onTap: () {
                                    final hasFile =
                                        doc.hasLocalFile || doc.mediaId != null;
                                    if (!hasFile &&
                                        canCreate &&
                                        access.canEditRecord(doc.createdBy) &&
                                        !locked) {
                                      context.push(
                                        AppRoutes.documentEdit(doc.id),
                                      );
                                    } else {
                                      context.push(
                                        AppRoutes.documentView(doc.id),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadError = document.localFilePath == null
        ? null
        : ref
              .watch(documentUploadErrorProvider(document.localFilePath!))
              .valueOrNull;
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final isImage =
        document.localFilePath != null &&
        (document.localFilePath!.endsWith('.jpg') ||
            document.localFilePath!.endsWith('.jpeg') ||
            document.localFilePath!.endsWith('.png'));

    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _categoryColor(
                    document.category,
                    tokens,
                  ).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: isImage && document.localFilePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radius.sm),
                        child: Image.file(
                          File(document.localFilePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        _categoryIcon(document.category),
                        color: _categoryColor(document.category, tokens),
                        size: 24,
                      ),
              ),
              SizedBox(width: tokens.space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!document.isSynced)
                      Text(
                        uploadError == 'LIMIT_EXCEEDED'
                            ? 'Waiting for storage space'
                            : 'Pending upload',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    SizedBox(height: tokens.space.s1),
                    Row(
                      children: [
                        Text(
                          _categoryLabel(document.category, s),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        ),
                        SizedBox(width: tokens.space.s2),
                        Text('·', style: TextStyle(color: tokens.text.caption)),
                        SizedBox(width: tokens.space.s2),
                        Text(
                          DateFormat.yMMMd().format(document.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.caption),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!document.isSynced) ...[
                SizedBox(width: tokens.space.s2),
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: tokens.feedback.queuedSync,
                ),
              ],
              SizedBox(width: tokens.space.s2),
              Icon(Icons.chevron_right, color: tokens.icon.inactive),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(DocumentCategory category, DcoTokens tokens) =>
      switch (category) {
        DocumentCategory.insurance => tokens.chart.insurance,
        DocumentCategory.registration => tokens.status.infoFg,
        DocumentCategory.invoice => tokens.status.successFg,
        DocumentCategory.warranty => tokens.status.warningFg,
        DocumentCategory.receipt => tokens.chart.tolls,
        DocumentCategory.other => tokens.text.tertiary,
      };

  IconData _categoryIcon(DocumentCategory category) => switch (category) {
    DocumentCategory.insurance => Icons.shield_outlined,
    DocumentCategory.registration => Icons.description_outlined,
    DocumentCategory.invoice => Icons.receipt_long_outlined,
    DocumentCategory.warranty => Icons.verified_outlined,
    DocumentCategory.receipt => Icons.confirmation_number_outlined,
    DocumentCategory.other => Icons.insert_drive_file_outlined,
  };

  String _categoryLabel(DocumentCategory category, AppLocalizations s) =>
      switch (category) {
        DocumentCategory.insurance => s.documentCategoryInsurance,
        DocumentCategory.registration => s.documentCategoryRegistration,
        DocumentCategory.invoice => s.documentCategoryInvoice,
        DocumentCategory.warranty => s.documentCategoryWarranty,
        DocumentCategory.receipt => s.documentCategoryReceipt,
        DocumentCategory.other => s.documentCategoryOther,
      };
}
