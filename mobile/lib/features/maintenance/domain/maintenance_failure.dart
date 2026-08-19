sealed class MaintenanceFailure implements Exception {
  const MaintenanceFailure(this.message);
  final String message;
}

class MaintenanceValidationFailure extends MaintenanceFailure {
  const MaintenanceValidationFailure(super.message);
}

class MileageDecreaseFailure extends MaintenanceFailure {
  const MileageDecreaseFailure([super.message = 'Mileage cannot decrease']);
}

class VehicleNotFoundFailure extends MaintenanceFailure {
  const VehicleNotFoundFailure([super.message = 'Vehicle not found']);
}

class PlanItemNotFoundFailure extends MaintenanceFailure {
  const PlanItemNotFoundFailure([super.message = 'Plan item not found']);
}

class ServiceRecordNotFoundFailure extends MaintenanceFailure {
  const ServiceRecordNotFoundFailure([super.message = 'Service record not found']);
}
