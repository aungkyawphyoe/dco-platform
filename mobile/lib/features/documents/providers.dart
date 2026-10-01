import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(documentRepositoryProvider).watchForVehicle(vehicleId);
});

/// Same data as [vehicleDocumentsProvider], keyed by an explicit vehicle id
/// so the vehicle detail screen can render for a non-active vehicle.
final documentsForVehicleProvider =
    StreamProvider.family<List<Document>, String>((ref, vehicleId) {
  if (vehicleId.isEmpty) return Stream.value(const []);
  return ref.watch(documentRepositoryProvider).watchForVehicle(vehicleId);
});
