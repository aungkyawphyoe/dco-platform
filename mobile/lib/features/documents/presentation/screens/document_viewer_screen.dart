import 'dart:io';

import 'package:dco_mobile/core/analytics/analytics.dart';
import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:dco_mobile/core/router/routes.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  Document? _document;
  bool _loading = true;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final doc = await ref
        .read(documentRepositoryProvider)
        .getById(widget.documentId);
    if (doc != null && mounted) {
      setState(() {
        _document = doc;
        _loading = false;
      });
      ref.read(analyticsProvider).track(AnalyticsEvent.documentOpened);
    } else if (mounted) {
      setState(() {
        _missing = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.documentViewerTitle)),
        body: Center(child: CircularProgressIndicator(color: tokens.text.accent)),
      );
    }

    if (_missing || _document == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.documentViewerTitle)),
        body: DcoEmptyState(
          title: s.documentViewerNotFound,
          body: s.documentViewerNotFoundBody,
        ),
      );
    }

    final doc = _document!;
    final isImage = doc.localFilePath != null &&
        (doc.localFilePath!.endsWith('.jpg') ||
            doc.localFilePath!.endsWith('.jpeg') ||
            doc.localFilePath!.endsWith('.png'));

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name),
        actions: [
          IconButton(
            tooltip: s.documentViewerEdit,
            onPressed: () => context.push(AppRoutes.documentEdit(doc.id)),
            icon: Icon(Icons.edit_outlined, color: tokens.icon.active),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: doc.hasLocalFile
                ? isImage
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(
                            File(doc.localFilePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : _PdfViewer(path: doc.localFilePath!)
                : doc.mediaId != null
                    ? _RemoteDocument(doc: doc)
                    : DcoEmptyState(
                        title: s.documentViewerNoFile,
                        body: s.documentViewerNoFileBody,
                      ),
          ),
          _DocumentInfoBar(document: doc),
        ],
      ),
    );
  }
}

class _PdfViewer extends StatelessWidget {
  const _PdfViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              size: 64, color: tokens.status.dangerFg),
          SizedBox(height: tokens.space.s4),
          Text(
            path.split('/').last,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.space.s4),
          DcoButton(
            label: 'Open PDF',
            onPressed: () async {
              await OpenFile.open(path);
            },
          ),
        ],
      ),
    );
  }
}

class _RemoteDocument extends ConsumerWidget {
  const _RemoteDocument({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_download_outlined,
              size: 64, color: tokens.icon.inactive),
          SizedBox(height: tokens.space.s4),
          Text(
            s.documentViewerRemote,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.space.s2),
          Text(
            s.documentViewerRemoteBody,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.text.caption),
          ),
        ],
      ),
    );
  }
}

class _DocumentInfoBar extends StatelessWidget {
  const _DocumentInfoBar({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(tokens.space.s4),
      decoration: BoxDecoration(
        color: tokens.background.card,
        border: Border(
          top: BorderSide(color: tokens.border.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            label: s.documentInfoCategory,
            value: _categoryLabel(document.category, s),
          ),
          SizedBox(height: tokens.space.s2),
          _InfoRow(
            label: s.documentInfoAdded,
            value: _formatDate(document.createdAt),
          ),
          if (document.notes != null && document.notes!.isNotEmpty) ...[
            SizedBox(height: tokens.space.s2),
            _InfoRow(
              label: s.documentInfoNotes,
              value: document.notes!,
            ),
          ],
          SizedBox(height: tokens.space.s2),
          _InfoRow(
            label: s.documentInfoStatus,
            value: document.isSynced
                ? s.documentStatusSynced
                : s.documentStatusQueued,
            valueColor: document.isSynced
                ? tokens.status.successFg
                : tokens.feedback.queuedSync,
          ),
        ],
      ),
    );
  }

  String _categoryLabel(DocumentCategory category, AppLocalizations s) =>
      switch (category) {
        DocumentCategory.insurance => s.documentCategoryInsurance,
        DocumentCategory.registration => s.documentCategoryRegistration,
        DocumentCategory.invoice => s.documentCategoryInvoice,
        DocumentCategory.warranty => s.documentCategoryWarranty,
        DocumentCategory.receipt => s.documentCategoryReceipt,
        DocumentCategory.other => s.documentCategoryOther,
      };

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: tokens.text.caption),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: valueColor ?? tokens.text.primary,
                ),
          ),
        ),
      ],
    );
  }
}
