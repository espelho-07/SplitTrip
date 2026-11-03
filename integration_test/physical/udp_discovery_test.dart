import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TEST 5: UDP Peer Discovery Socket & Latency', () {
    testWidgets('binds UDP sockets, broadcasts discovery beacon, and measures latency', (tester) async {
      // 1. Bind receiver socket on any available loopback port
      final receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final receiverPort = receiver.port;

      // 2. Bind sender socket
      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);

      final beacon = {
        'tag': 'kith_p2p_v1',
        'deviceId': 'device-test-01',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final beaconBytes = utf8.encode(jsonEncode(beacon));

      final completer = Completer<Datagram>();
      final stopwatch = Stopwatch()..start();

      final subscription = receiver.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = receiver.receive();
          if (dg != null && !completer.isCompleted) {
            stopwatch.stop();
            completer.complete(dg);
          }
        }
      });

      // Send beacon
      sender.send(beaconBytes, InternetAddress.loopbackIPv4, receiverPort);

      // Await datagram with timeout
      final datagram = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('UDP beacon receive timed out'),
      );

      expect(datagram, isNotNull);
      final receivedData = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      expect(receivedData['tag'], equals('kith_p2p_v1'));
      expect(receivedData['deviceId'], equals('device-test-01'));

      // Latency on local socket should be under 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      await subscription.cancel();
      sender.close();
      receiver.close();
    });
  });
}
