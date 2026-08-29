import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/core/utils/error_formatter.dart';

void main() {
  group('KithErrorFormatter Unit Tests (User-Friendly Error Handling)', () {
    test('1. Formats NotFoundException into human-friendly trip message', () {
      const err = NotFoundException(message: 'Trip not found');
      final formatted = KithErrorFormatter.format(err);
      expect(formatted, 'No trip found for this invite code. Please check the code and try again.');
      expect(formatted.contains('ApiException'), isFalse);
      expect(formatted.contains('404'), isFalse);
    });

    test('2. Formats generic ApiException [NOT_FOUND] into clean message', () {
      const err = ApiException(
        message: 'Trip not found',
        code: 'NOT_FOUND',
        statusCode: 404,
      );
      final formatted = KithErrorFormatter.format(err);
      expect(formatted, 'No trip found for this invite code. Please check the code and try again.');
    });

    test('3. Formats NetworkException into polite connectivity message', () {
      const err = NetworkException();
      final formatted = KithErrorFormatter.format(err);
      expect(formatted, 'Unable to connect to the server. Please check your internet connection.');
    });

    test('4. Formats SocketException and offline errors into polite message', () {
      final err = const SocketException('Failed host lookup: server.com');
      final formatted = KithErrorFormatter.format(err);
      expect(formatted, 'Unable to connect to the server. Please check your internet connection.');
    });

    test('5. Formats raw technical strings like "ApiException [NOT_FOUND] (404): Trip not found"', () {
      const raw = 'ApiException [NOT_FOUND] (404): Trip not found';
      final formatted = KithErrorFormatter.format(raw);
      expect(formatted, 'No trip found for this invite code. Please check the code and try again.');
    });

    test('6. Formats ValidationException into clear guidance', () {
      const err = ValidationException(message: 'Please enter a valid 6-character code');
      final formatted = KithErrorFormatter.format(err);
      expect(formatted, 'Please enter a valid 6-character code');
      expect(formatted.contains('ValidationException'), isFalse);
    });
  });
}
