import 'package:dco_mobile/core/providers.dart';
import 'package:dco_mobile/features/documents/domain/entities/document.dart';
import 'package:dco_mobile/features/garage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final vehicleId = ref.watch(activeVehicleProvider).valueOrNull?.id;
  if (vehicleId == null) return Stream.value(const []);
  return ref.watch(documentRepositoryProvider).watchForVehicle(vehicleId);
});
