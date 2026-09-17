sealed class DocumentFailure {
  const DocumentFailure();
}

class DocumentNotFoundFailure extends DocumentFailure {
  const DocumentNotFoundFailure();
}

class DocumentValidationFailure extends DocumentFailure {
  const DocumentValidationFailure(this.message);
  final String message;
}

class DocumentTooLargeFailure extends DocumentFailure {
  const DocumentTooLargeFailure();
}
