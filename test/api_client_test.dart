import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';

void main() {
  group('ApiClient Tests', () {
    test('Injects Bearer token in headers when configured', () async {
      late http.BaseRequest capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'data': {'status': 'ok'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      apiClient.setAuthToken('test_session_token_123');

      final res = await apiClient.get('/auth/me');

      expect(capturedRequest.headers['authorization'], 'Bearer test_session_token_123');
      expect(res, {'status': 'ok'});
    });

    test('Throws ValidationException on 400 response with server error details', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'BAD_REQUEST',
              'message': 'Split sum mismatch: Total ₹100 does not equal sum ₹90',
            }
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      expect(
        () => apiClient.post('/trips/trip_1/expenses', body: {'amount': 100}),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Split sum mismatch'),
        )),
      );
    });

    test('Throws UnauthorizedException on 401 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Session expired'}
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      expect(
        () => apiClient.get('/trips'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('Throws ForbiddenException on 403 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN', 'message': 'Only creator can complete trip'}
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);

      expect(
        () => apiClient.patch('/trips/trip_1/lifecycle', body: {'lifecycleState': 'completed'}),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}
