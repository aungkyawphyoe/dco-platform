import 'dart:typed_data';

import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

final _incidents = FutureProvider.autoDispose
    .family<({List<_Incident> items, bool hasMore}), (String, int)>((
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
            .map(_Incident.fromJson)
            .toList(),
        hasMore: json['hasMore'] == true,
      );
    });

class _Incident {
  _Incident.fromJson(Map<String, dynamic> json)
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

String _category(AppLocalizations l10n, String value) => switch (value) {
  'accident' => l10n.incidentAccident,
  'breakdown' => l10n.incidentBreakdown,
  'damage' => l10n.incidentDamage,
  _ => l10n.incidentOther,
};

String _dateLabel(BuildContext context, DateTime date) {
  final local = MaterialLocalizations.of(context);
  return '${local.formatMediumDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class DriverIncidentsScreen extends ConsumerStatefulWidget {
  const DriverIncidentsScreen({super.key});

  @override
  ConsumerState<DriverIncidentsScreen> createState() =>
      _DriverIncidentsScreenState();
}

class _DriverIncidentsScreenState extends ConsumerState<DriverIncidentsScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orgId = ref.watch(entitlementsProvider).valueOrNull?.organization?.id;
    final vehicle = ref.watch(activeVehicleProvider).valueOrNull;
    final vehicleNames = {
      for (final item in ref.watch(garageVehiclesProvider).valueOrNull ?? [])
        item.id: item.name,
    };
    final key = orgId == null ? null : (orgId, _page);
    final state = key == null ? null : ref.watch(_incidents(key));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.incidentTitle)),
      body: key == null || state == null
          ? const Center(child: Text('Fleet access is required.'))
          : state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(_incidents(key)),
                  child: Text(l10n.incidentRetryList),
                ),
              ),
              data: (result) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_incidents(key));
                  await ref.read(_incidents(key).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (result.items.isEmpty)
                      const ListTile(title: Text('No incidents to show.')),
                    for (final incident in result.items)
                      ListTile(
                        title: Text(
                          '${_category(l10n, incident.category)} · ${incident.closed ? l10n.incidentClosed : l10n.incidentOpen}',
                        ),
                        subtitle: Text(
                          '${vehicleNames[incident.vehicleId] ?? incident.vehicleId} · ${_dateLabel(context, incident.eventAt)}\n${incident.description}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _IncidentDetail(
                              orgId: key.$1,
                              incidentId: incident.id,
                            ),
                          ),
                        ),
                      ),
                    if (_page > 1 || result.hasMore)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            child: Text(l10n.incidentPrevious),
                          ),
                          TextButton(
                            onPressed: result.hasMore
                                ? () => setState(() => _page++)
                                : null,
                            child: Text(l10n.incidentNext),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: orgId == null || vehicle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => _IncidentForm(
                      orgId: orgId,
                      vehicleId: vehicle.id,
                      vehicleName: vehicle.name,
                    ),
                  ),
                );
                if (created != true || !mounted) return;
                ref.invalidate(_incidents((orgId, 1)));
                setState(() => _page = 1);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Incident submitted.')),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.incidentReport),
            ),
    );
  }
}

final _incidentDetails = FutureProvider.autoDispose
    .family<_Incident, (String, String)>((ref, key) async {
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>(
            '/organizations/${key.$1}/incidents/${key.$2}',
          );
      return _Incident.fromJson(response.data!);
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

class _IncidentDetail extends ConsumerWidget {
  const _IncidentDetail({required this.orgId, required this.incidentId});
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
                  '${_category(l10n, incident.category)} · ${incident.closed ? l10n.incidentClosed : l10n.incidentOpen}',
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

class _IncidentForm extends ConsumerStatefulWidget {
  const _IncidentForm({
    required this.orgId,
    required this.vehicleId,
    required this.vehicleName,
  });
  final String orgId, vehicleId, vehicleName;

  @override
  ConsumerState<_IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends ConsumerState<_IncidentForm> {
  final _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _id = const Uuid().v4();
  final _photos = <({String id, XFile file})>[];
  var _event = DateTime.now();
  var _categoryValue = 'breakdown';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _event,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_event),
    );
    if (time == null || !mounted) return;
    setState(
      () => _event = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
        limit: 5 - _photos.length,
      );
      if (!mounted) return;
      setState(() {
        _photos.addAll(
          files
              .take(5 - _photos.length)
              .map((file) => (id: const Uuid().v4(), file: file)),
        );
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = l10n.incidentPickerError);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final dio = ref.read(dioProvider);
    try {
      for (final photo in _photos) {
        await dio.post(
          '/media',
          data: FormData.fromMap({
            'id': photo.id,
            'purpose': 'incident_photo',
            'vehicle_id': widget.vehicleId,
            'file': await MultipartFile.fromFile(photo.file.path),
          }),
        );
      }
      await dio.post(
        '/organizations/${widget.orgId}/incidents',
        data: {
          'id': _id,
          'vehicle_id': widget.vehicleId,
          'event_at': _event.toUtc().toIso8601String(),
          'category': _categoryValue,
          'description': _description.text.trim(),
          'photo_ids': _photos.map((photo) => photo.id).toList(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.incidentSubmitError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.incidentReport)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.vehicleName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.incidentEventTime),
              subtitle: Text(_dateLabel(context, _event)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _saving ? null : _chooseTime,
            ),
            DropdownButtonFormField<String>(
              initialValue: _categoryValue,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['accident', 'breakdown', 'damage', 'other']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_category(l10n, value)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _categoryValue = value);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.incidentDescriptionRequired
                  : null,
            ),
            for (final photo in _photos)
              ListTile(
                title: Text(photo.file.name),
                trailing: IconButton(
                  tooltip: l10n.incidentRemovePhoto,
                  icon: const Icon(Icons.close),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _photos.remove(photo)),
                ),
              ),
            OutlinedButton(
              onPressed: _saving || _photos.length >= 5 ? null : _pickPhotos,
              child: Text('${l10n.incidentAddPhotos} (${_photos.length}/5)'),
            ),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving ? l10n.incidentSubmitting : l10n.incidentSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
