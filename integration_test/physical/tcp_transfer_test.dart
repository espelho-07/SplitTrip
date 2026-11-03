import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 6: TCP / HTTP Server Authenticated Transfer', () {
    testWidgets('accepts authenticated requests and rejects unauthorized requests', (tester) async {
      // 1. Start local HTTP server
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      const expectedAuthToken = 'valid_hmac_auth_token_12345';

      server.listen((HttpRequest request) async {
        final authHeader = request.headers.value('x-kith-signature');
        if (authHeader == expectedAuthToken) {
          final body = await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ACK', 'received': body.length}))
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write(jsonEncode({'error': 'UNAUTHORIZED_SIGNATURE'}))
            ..close();
        }
      });

      final client = HttpClient();

      // 2. Test valid authenticated request
      final validReq = await client.post(InternetAddress.loopbackIPv4.address, server.port, '/sync');
      validReq.headers.add('x-kith-signature', expectedAuthToken);
      validReq.write(jsonEncode({'op': 'CREATE_EXPENSE', 'id': 'exp-01'}));
      final validRes = await validReq.close();
      expect(validRes.statusCode, equals(HttpStatus.ok));

      // 3. Test invalid request (missing or invalid header)
      final invalidReq = await client.post(InternetAddress.loopbackIPv4.address, server.port, '/sync');
      invalidReq.headers.add('x-kith-signature', 'bad_token');
      final invalidRes = await invalidReq.close();
      expect(invalidRes.statusCode, equals(HttpStatus.unauthorized));

      client.close();
      await server.close(force: true);
    });
  });
}
