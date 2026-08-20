sealed class FuelFailure implements Exception {
  const FuelFailure(this.message);
  final String message;
}

class FuelValidationFailure extends FuelFailure {
  const FuelValidationFailure(super.message);
}

class DuplicateFuelTypeNameFailure extends FuelFailure {
  const DuplicateFuelTypeNameFailure([super.message = 'That fuel type is already in your catalog']);
}

class FuelTypeNotFoundFailure extends FuelFailure {
  const FuelTypeNotFoundFailure([super.message = 'Fuel type not found']);
}

class FuelLogNotFoundFailure extends FuelFailure {
  const FuelLogNotFoundFailure([super.message = 'Log not found']);
}

class FuelTypeKindMismatchFailure extends FuelFailure {
  const FuelTypeKindMismatchFailure([
    super.message = 'That fuel type does not match this vehicle',
  ]);
}
