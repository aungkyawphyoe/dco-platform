sealed class PartFailure implements Exception {
  const PartFailure(this.message);
  final String message;
}

class PartValidationFailure extends PartFailure {
  const PartValidationFailure(super.message);
}

class DuplicatePartNameFailure extends PartFailure {
  const DuplicatePartNameFailure([super.message = 'That part is already in this vehicle']);
}

class PartNotFoundFailure extends PartFailure {
  const PartNotFoundFailure([super.message = 'Part not found']);
}
