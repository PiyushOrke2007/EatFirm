import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/core/network/api_exception.dart';

void main() {
  group('ApiClient Tests', () {
    test('Injects correlation ID header and parses success response', () async {
      String? capturedRequestId;

      final mockClient = MockClient((request) async {
        capturedRequestId = request.headers['X-Request-Id'];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'status': 'ok'},
            'meta': {
              'requestId': capturedRequestId ?? 'gen-123',
              'timestamp': DateTime.now().toIso8601String(),
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final response = await apiClient.get<Map<String, dynamic>>('/health');

      expect(response.success, isTrue);
      expect(response.data['status'], equals('ok'));
      expect(capturedRequestId, isNotNull);
      expect(capturedRequestId, startsWith('req-'));
    });

    test('Maps 422 error body into ValidationException with details', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Input was invalid',
              'details': [
                {'field': 'email', 'message': 'Must be valid format'},
              ],
            },
            'meta': {
              'requestId': 'req-test-422',
              'timestamp': DateTime.now().toIso8601String(),
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      expect(
        () => apiClient.post('/submit', body: {}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors?.first.field,
            'field',
            equals('email'),
          ),
        ),
      );
    });

    test('Maps 401 error into UnauthorizedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'UNAUTHORIZED', 'message': 'Auth required'},
          }),
          401,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      expect(
        () => apiClient.get('/protected'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('Maps 404 error into NotFoundException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'NOT_FOUND', 'message': 'Not found'},
          }),
          404,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      expect(
        () => apiClient.get('/missing'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
