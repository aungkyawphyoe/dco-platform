import 'dart:typed_data';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final driverIncidentsProvider = FutureProvider.autoDispose
    .family<({List<DriverIncident> items, bool hasMore}), (String, int)>((
      ref,
      key,
    ) async {
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>(
            '/organizations/${key.$1}/incidents',
            queryParameters: {'page': key.$2},
          );
      final json = response.data!;
      return (
        items: (json['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map(DriverIncident.fromJson)
            .toList(),
        hasMore: json['hasMore'] == true,
      );
    });

void refreshDriverIncidents(WidgetRef ref) =>
    ref.invalidate(driverIncidentsProvider);

class DriverIncident {
  DriverIncident.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      vehicleId = json['vehicleId'] as String,
      category = json['category'] as String,
      description = json['description'] as String,
      eventAt = DateTime.parse(json['eventAt'] as String).toLocal(),
      closed = json['closedAt'] != null,
      note = json['reviewNote'] as String?,
      photos = (json['photoIds'] as List?)?.whereType<String>().toList() ?? [],
      repairs =
          (json['repairs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((repair) => '${repair['description']} · ${repair['status']}')
              .toList() ??
          [];

  final String id, vehicleId, category, description;
  final String? note;
  final DateTime eventAt;
  final bool closed;
  final List<String> photos, repairs;
}

String incidentCategoryLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'accident' => l10n.incidentAccident,
      'breakdown' => l10n.incidentBreakdown,
      'damage' => l10n.incidentDamage,
      _ => l10n.incidentOther,
    };

String _dateLabel(BuildContext context, DateTime date) {
  final local = MaterialLocalizations.of(context);
  return '${local.formatMediumDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

final _incidentDetails = FutureProvider.autoDispose
    .family<DriverIncident, (String, String)>((ref, key) async {
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>(
            '/organizations/${key.$1}/incidents/${key.$2}',
          );
      return DriverIncident.fromJson(response.data!);
    });

final _incidentPhoto = FutureProvider.autoDispose.family<Uint8List, String>((
  ref,
  path,
) async {
  final response = await ref
      .watch(dioProvider)
      .get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
  return Uint8List.fromList(response.data!);
});

class DriverIncidentDetail extends ConsumerWidget {
  const DriverIncidentDetail({
    super.key,
    required this.orgId,
    required this.incidentId,
  });
  final String orgId, incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final key = (orgId, incidentId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.incidentDetails)),
      body: ref
          .watch(_incidentDetails(key))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(_incidentDetails(key)),
                child: Text(l10n.incidentRetryDetails),
              ),
            ),
            data: (incident) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${incidentCategoryLabel(l10n, incident.category)} · ${incident.closed ? l10n.incidentClosed : l10n.incidentOpen}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(_dateLabel(context, incident.eventAt)),
                const SizedBox(height: 12),
                Text(incident.description),
                if (incident.note case final note?) ...[
                  const SizedBox(height: 12),
                  Text('${l10n.incidentReviewNote}: $note'),
                ],
                for (final repair in incident.repairs)
                  ListTile(title: Text(repair)),
                for (final id in incident.photos)
                  ref
                      .watch(
                        _incidentPhoto(
                          '/organizations/$orgId/incidents/$incidentId/photos/$id',
                        ),
                      )
                      .when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (_, _) => Text(l10n.incidentPhotoUnavailable),
                        data: (bytes) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Image.memory(
                            bytes,
                            gaplessPlayback: false,
                            semanticLabel: l10n.incidentPhoto,
                          ),
                        ),
                      ),
              ],
            ),
          ),
    );
  }
}
