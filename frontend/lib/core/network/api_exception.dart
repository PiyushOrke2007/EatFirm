/// Base exception for all API-related failures in EatFirm.
class ApiException implements Exception {
  final String message;
  final String code;
  final int statusCode;
  final String? requestId;
  final List<ApiFieldError>? fieldErrors;

  const ApiException({
    required this.message,
    this.code = 'UNKNOWN_ERROR',
    this.statusCode = 500,
    this.requestId,
    this.fieldErrors,
  });

  @override
  String toString() =>
      'ApiException: [$statusCode - $code] $message (requestId: $requestId)';
}

/// Represents individual field-level validation errors from the backend.
class ApiFieldError {
  final String? field;
  final String message;
  final String? code;

  const ApiFieldError({this.field, required this.message, this.code});

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field'] as String?,
      message: (json['message'] as String?) ?? 'Invalid value',
      code: json['code'] as String?,
    );
  }
}

class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.statusCode = 422,
    super.requestId,
    super.fieldErrors,
  });
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = 'Authentication required',
    super.code = 'UNAUTHORIZED',
    super.statusCode = 401,
    super.requestId,
  });
}

class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message = 'Access denied for your role or credentials',
    super.code = 'FORBIDDEN',
    super.statusCode = 403,
    super.requestId,
  });
}

class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'Resource not found',
    super.code = 'NOT_FOUND',
    super.statusCode = 404,
    super.requestId,
  });
}

class ConflictException extends ApiException {
  const ConflictException({
    super.message = 'Resource conflict',
    super.code = 'CONFLICT',
    super.statusCode = 409,
    super.requestId,
  });
}

class NetworkException extends ApiException {
  const NetworkException({
    super.message =
        'Unable to reach the server. Please check your internet connection.',
    super.code = 'NETWORK_ERROR',
    super.statusCode = 0,
    super.requestId,
  });
}

class ServerException extends ApiException {
  const ServerException({
    super.message = 'An unexpected server error occurred',
    super.code = 'INTERNAL_SERVER_ERROR',
    super.statusCode = 500,
    super.requestId,
  });
}
