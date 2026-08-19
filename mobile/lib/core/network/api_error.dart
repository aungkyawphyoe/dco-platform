class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  factory ApiError.fromBody(Map<String, dynamic> json, {int? statusCode}) {
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      return ApiError(
        code: error['code'] as String? ?? 'unknown',
        message: error['message'] as String? ?? 'Something went wrong',
        statusCode: statusCode,
        details: error['details'] is Map<String, dynamic>
            ? error['details'] as Map<String, dynamic>
            : const {},
      );
    }
    return ApiError(
      code: 'unknown',
      message: 'Something went wrong',
      statusCode: statusCode,
    );
  }

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  @override
  String toString() => 'ApiError($code, $message)';
}
