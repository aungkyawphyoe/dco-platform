import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_card.dart';
import 'package:dco_mobile/core/widgets/dco_empty_state.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/fleet/presentation/fleet_labels.dart';
import 'package:dco_mobile/features/fleet/providers.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'driver_incidents_screen.dart' show refreshDriverIncidents;

class DriverReportIssueScreen extends ConsumerWidget {
  const DriverReportIssueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context)!;
    final org = ref.watch(entitlementsProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);
    final orgId = org.valueOrNull?.organization?.id;
    final vehicle = activeVehicle.valueOrNull;
    if (orgId != null && vehicle != null) {
      return _ReportForm(
        key: ValueKey((orgId, vehicle.id)),
        orgId: orgId,
        vehicleId: vehicle.id,
        vehicleName: vehicle.displayName,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.fleetWoReportTitle)),
      body: org.isLoading || activeVehicle.isLoading
          ? const Center(child: CircularProgressIndicator())
          : DcoEmptyState(
              title: orgId == null
                  ? s.fleetNoAccessTitle
                  : s.driverNoVehicleTitle,
              body: orgId == null ? s.fleetNoAccessBody : s.driverNoVehicleBody,
            ),
    );
  }
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({
    super.key,
    required this.orgId,
    required this.vehicleId,
    required this.vehicleName,
  });

  final String orgId;
  final String vehicleId;
  final String vehicleName;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  static const _issueTypes = <String, IconData>{
    'accident': Icons.car_crash_outlined,
    'breakdown': Icons.build_outlined,
    'wear_tear': Icons.tire_repair_outlined,
    'scheduled_service': Icons.event_outlined,
    'other': Icons.more_horiz,
  };
  static const _photoLimit = 5;

  final _odometer = TextEditingController();
  final _description = TextEditingController();
  final _incidentId = const Uuid().v4();
  final _photos = <({String id, XFile file})>[];
  DateTime? _event;
  String? _issueType;
  String _urgency = 'medium';
  String? _descriptionError, _odometerError, _requestError;
  bool _saving = false;
  bool _picking = false;

  bool get _accident => _issueType == 'accident';

  @override
  void dispose() {
    _odometer.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseTime() async {
    final initial = _event ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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
    final s = AppLocalizations.of(context)!;
    final remaining = _photoLimit - _photos.length;
    if (_picking || remaining <= 0) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (remaining == 1) {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        files = [?file];
      } else {
        files = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
          limit: remaining,
        );
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(
          files
              .take(remaining)
              .map((file) => (id: const Uuid().v4(), file: file)),
        );
        _requestError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _requestError = s.incidentPickerError);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final issue = _issueType;
    if (issue == null || _saving || _picking) return;
    final s = AppLocalizations.of(context)!;
    final description = _description.text.trim();
    final odometer = int.tryParse(_odometer.text.trim());
    setState(() {
      _descriptionError = description.length < (_accident ? 1 : 10)
          ? (_accident
                ? s.incidentDescriptionRequired
                : s.fleetWoDescriptionHint)
          : null;
      _odometerError =
          !_accident &&
              (odometer == null || odometer < 0 || odometer > 2147483647)
          ? s.required
          : null;
      _requestError = null;
    });
    if (_descriptionError != null || _odometerError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      if (_accident) {
        final dio = ref.read(dioProvider);
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
            'id': _incidentId,
            'vehicle_id': widget.vehicleId,
            'event_at': (_event ?? DateTime.now()).toUtc().toIso8601String(),
            'category': 'accident',
            'description': description,
            'photo_ids': _photos.map((photo) => photo.id).toList(),
          },
        );
      } else {
        await ref
            .read(fleetRepositoryProvider)
            .createWorkOrder(
              widget.orgId,
              vehicleId: widget.vehicleId,
              odometerKm: odometer!,
              issueType: issue,
              description: description,
              urgency: _urgency,
            );
      }
      if (!mounted) return;
      if (_accident) {
        refreshDriverIncidents(ref);
      } else {
        ref.invalidate(driverWorkOrdersProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_accident ? s.incidentSubmitted : s.fleetWoReported),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final response = error is DioException ? error.response?.data : null;
      final problem = response is Map ? response['error'] : null;
      final conflict =
          _accident &&
          problem is Map &&
          problem['code'] == 'incident_id_conflict';
      setState(() {
        _saving = false;
        _requestError = conflict
            ? s.incidentSubmissionConflict
            : _accident
            ? s.incidentSubmitError
            : s.fleetActionFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final gap = SizedBox(height: tokens.space.s4);
    final dateLabels = MaterialLocalizations.of(context);
    final event = _event ?? DateTime.now();
    final eventLabel =
        '${dateLabels.formatMediumDate(event)}, '
        '${dateLabels.formatTimeOfDay(TimeOfDay.fromDateTime(event))}';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(s.fleetWoReportTitle)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.all(tokens.space.s5),
              children: [
                DcoCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        color: tokens.text.accent,
                      ),
                      SizedBox(width: tokens.space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.fleetWoVehicle,
                              style: theme.textTheme.labelMedium,
                            ),
                            Text(
                              widget.vehicleName,
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                gap,
                Text(s.fleetWoIssueType, style: theme.textTheme.titleMedium),
                SizedBox(height: tokens.space.s2),
                Wrap(
                  spacing: tokens.space.s2,
                  runSpacing: tokens.space.s2,
                  children: [
                    for (final entry in _issueTypes.entries)
                      ChoiceChip(
                        showCheckmark: false,
                        selectedColor: tokens.button.primary.background,
                        labelStyle: TextStyle(
                          color: _issueType == entry.key
                              ? tokens.text.onAccent
                              : tokens.text.primary,
                        ),
                        label: Text(issueTypeLabel(s, entry.key)),
                        avatar: Icon(
                          entry.value,
                          size: 18,
                          color: _issueType == entry.key
                              ? tokens.text.onAccent
                              : tokens.icon.inactive,
                        ),
                        selected: _issueType == entry.key,
                        onSelected: _saving || _picking
                            ? null
                            : (selected) {
                                if (!selected) return;
                                setState(() {
                                  if (entry.key == 'accident') {
                                    _event ??= DateTime.now();
                                  }
                                  _issueType = entry.key;
                                  _descriptionError = null;
                                  _odometerError = null;
                                  _requestError = null;
                                });
                              },
                      ),
                  ],
                ),
                if (_issueType != null) ...[
                  gap,
                  DcoTextField(
                    controller: _description,
                    label: s.fleetWoDescription,
                    hint: _accident ? null : s.fleetWoDescriptionHint,
                    errorText: _descriptionError,
                    readOnly: _saving,
                    maxLength: 2000,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),
                  gap,
                  if (_accident) ...[
                    DcoCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.schedule_outlined),
                        title: Text(s.incidentEventTime),
                        subtitle: Text(eventLabel),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _saving ? null : _chooseTime,
                      ),
                    ),
                    SizedBox(height: tokens.space.s2),
                    for (final photo in _photos)
                      ListTile(
                        leading: const Icon(Icons.photo_outlined),
                        title: Text(
                          photo.file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: s.incidentRemovePhoto,
                          icon: const Icon(Icons.close),
                          onPressed: _saving || _picking
                              ? null
                              : () => setState(() => _photos.remove(photo)),
                        ),
                      ),
                    DcoButton(
                      label:
                          '${s.incidentAddPhotos} (${_photos.length}/$_photoLimit)',
                      icon: Icons.add_photo_alternate_outlined,
                      variant: DcoButtonVariant.secondary,
                      loading: _picking,
                      onPressed: _saving || _photos.length >= _photoLimit
                          ? null
                          : _pickPhotos,
                    ),
                  ] else ...[
                    DcoTextField(
                      controller: _odometer,
                      label: s.fleetWoOdometerKm,
                      errorText: _odometerError,
                      readOnly: _saving,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: tokens.space.s3),
                    DropdownButtonFormField<String>(
                      initialValue: _urgency,
                      decoration: InputDecoration(labelText: s.fleetWoUrgency),
                      items: [
                        for (final urgency in const [
                          'low',
                          'medium',
                          'high',
                          'critical',
                        ])
                          DropdownMenuItem(
                            value: urgency,
                            child: Text(urgencyLabel(s, urgency)),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _urgency = value ?? 'medium'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: EdgeInsets.all(tokens.space.s4),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_requestError case final error?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    SizedBox(height: tokens.space.s2),
                  ],
                  DcoButton(
                    label: s.fleetWoReportSubmit,
                    loading: _saving,
                    onPressed: _issueType == null || _picking ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
