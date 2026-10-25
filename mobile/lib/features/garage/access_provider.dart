import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/gating/providers.dart';
import 'domain/entities/vehicle.dart';
import 'domain/vehicle_access.dart';
export 'domain/vehicle_access.dart';

final _billingClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 15),
    (_) => DateTime.now().toUtc(),
  );
});

final vehicleAccessProvider = Provider.family<VehicleAccess, Vehicle?>((
  ref,
  vehicle,
) {
  final now =
      ref.watch(_billingClockProvider).valueOrNull ?? DateTime.now().toUtc();
  final userId = ref.watch(currentUserIdProvider);
  final claims = ref.watch(licenseControllerProvider).valueOrNull;
  final orgId = ref.watch(driverOrganizationIdProvider);
  var writable = claims != null;
  if (orgId != null) {
    writable =
        claims?.organizationId == orgId &&
        claims?.organizationWritable == true &&
        claims?.organizationAccessEnd?.isAfter(now) == true;
  } else if (vehicle?.userId == userId &&
      claims?.billingManaged == true &&
      claims?.planId == 'free') {
    writable = vehicle?.id == claims?.freeVehicleId;
  }
  return VehicleAccess.of(vehicle, userId, writable: writable);
});
