import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// Core HTTP client for communicating with the EatFirm REST backend.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  // Token provider hook for Module 02 authentication integration
  String? Function()? _authTokenProvider;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = AppConstants.defaultTimeout,
  }) : baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl,
       _httpClient = httpClient ?? http.Client();

  void setAuthTokenProvider(String? Function()? provider) {
    _authTokenProvider = provider;
  }

  /// Generates a random client correlation ID if none is supplied.
  String _generateCorrelationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'req-$now';
  }

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': _generateCorrelationId(),
    };

    if (_authTokenProvider != null) {
      final token = _authTokenProvider!();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final urlString = '$baseUrl$normalizedPath';
    final uri = Uri.parse(urlString);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return uri.replace(
        queryParameters: {...uri.queryParameters, ...stringParams},
      );
    }

    return uri;
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    return _sendRequest<T>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    return _sendRequest<T>(
      method: 'POST',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    return _sendRequest<T>(
      method: 'PUT',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    return _sendRequest<T>(
      method: 'PATCH',
      path: path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    return _sendRequest<T>(
      method: 'DELETE',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      fromJson: fromJson,
    );
  }

  Future<ApiResponse<T>> _sendRequest<T>({
    required String method,
    required String path,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final requestHeaders = _buildHeaders(extraHeaders: headers);

    try {
      final request = http.Request(method, uri);
      request.headers.addAll(requestHeaders);

      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse<T>(response, fromJson);
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Could not connect to EatFirm server: ${e.message}',
      );
    } on TimeoutException {
      throw const NetworkException(
        message: 'Request timed out. Please try again.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: 'Network error: $e');
    }
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    final statusCode = response.statusCode;
    Map<String, dynamic>? responseBody;

    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          responseBody = decoded;
        }
      }
    } catch (_) {
      // Non-JSON response body
    }

    final requestId =
        response.headers['x-request-id'] ??
        (responseBody?['meta']?['requestId'] as String?);

    // Success response: 2xx
    if (statusCode >= 200 && statusCode < 300) {
      if (responseBody != null && responseBody['success'] == true) {
        final dynamic rawData = responseBody['data'];
        final T parsedData = fromJson != null
            ? fromJson(rawData)
            : rawData as T;
        final meta = ApiMeta.fromJson(responseBody['meta'] ?? {});

        return ApiResponse<T>(success: true, data: parsedData, meta: meta);
      }

      // Fallback for empty body or standard responses
      return ApiResponse<T>(
        success: true,
        data: null as T,
        meta: ApiMeta(
          requestId: requestId ?? 'unknown',
          timestamp: DateTime.now(),
        ),
      );
    }

    // Error response handling
    final errorObject = responseBody?['error'] as Map<String, dynamic>?;
    final errorCode = (errorObject?['code'] as String?) ?? 'HTTP_$statusCode';
    final errorMessage =
        (errorObject?['message'] as String?) ??
        response.reasonPhrase ??
        'An error occurred';

    List<ApiFieldError>? fieldErrors;
    if (errorObject?['details'] is List) {
      fieldErrors = (errorObject!['details'] as List)
          .map((item) => ApiFieldError.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    switch (statusCode) {
      case 400:
        throw ApiException(
          message: errorMessage,
          code: errorCode,
          statusCode: 400,
          requestId: requestId,
          fieldErrors: fieldErrors,
        );
      case 401:
        throw UnauthorizedException(
          message: errorMessage,
          code: errorCode,
          statusCode: 401,
          requestId: requestId,
        );
      case 403:
        throw ForbiddenException(
          message: errorMessage,
          code: errorCode,
          statusCode: 403,
          requestId: requestId,
        );
      case 404:
        throw NotFoundException(
          message: errorMessage,
          code: errorCode,
          statusCode: 404,
          requestId: requestId,
        );
      case 409:
        throw ConflictException(
          message: errorMessage,
          code: errorCode,
          statusCode: 409,
          requestId: requestId,
        );
      case 422:
        throw ValidationException(
          message: errorMessage,
          code: errorCode,
          statusCode: 422,
          requestId: requestId,
          fieldErrors: fieldErrors,
        );
      case 500:
      default:
        throw ServerException(
          message: errorMessage,
          code: errorCode,
          statusCode: statusCode,
          requestId: requestId,
        );
    }
  }

  void close() {
    _httpClient.close();
  }
}
