sealed class VehicleFailure implements Exception {
  const VehicleFailure(this.message);
  final String message;
}

class VehicleValidationFailure extends VehicleFailure {
  const VehicleValidationFailure(super.message);
}

class DuplicatePlateFailure extends VehicleFailure {
  const DuplicatePlateFailure([
    super.message = 'That license plate is already in your garage',
  ]);
}

class DuplicateVinFailure extends VehicleFailure {
  const DuplicateVinFailure([super.message = 'That VIN already belongs to a vehicle']);
}

class MileageDecreaseFailure extends VehicleFailure {
  const MileageDecreaseFailure([
    super.message = 'Mileage cannot decrease',
  ]);
}

class VehicleNotFoundFailure extends VehicleFailure {
  const VehicleNotFoundFailure([super.message = 'Vehicle not found']);
}
