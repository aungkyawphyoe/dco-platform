import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'domain/entities/handover_receipt.dart';
import 'domain/entities/vehicle_warranty.dart';

/// Warranty delivered with a handover, keyed by vehicle id.
final vehicleWarrantyProvider = StreamProvider.family<VehicleWarranty?, String>(
  (ref, vehicleId) {
    if (vehicleId.isEmpty) return Stream.value(null);
    return ref.watch(handoverRepositoryProvider).watchWarranty(vehicleId);
  },
);

/// Latest handover receipt for a vehicle, keyed by vehicle id.
final vehicleHandoverReceiptProvider =
    StreamProvider.family<HandoverReceipt?, String>((ref, vehicleId) {
      if (vehicleId.isEmpty) return Stream.value(null);
      return ref.watch(handoverRepositoryProvider).watchReceipt(vehicleId);
    });
