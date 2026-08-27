import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/connectivity_guard.dart';
import 'package:kith_app/core/network/network_connectivity_service.dart';

class FakeConnectivityService implements NetworkConnectivityService {
  bool online;
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();

  FakeConnectivityService({this.online = true});

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  void dispose() => _controller.close();
}

void main() {
  group('ConnectivityGuard Tests', () {
    testWidgets('allows action when online', (tester) async {
      final fakeService = FakeConnectivityService(online: true);
      final guard = ConnectivityGuard(fakeService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final canProceed = await guard.checkOnlineOrNotify(
                    context,
                    actionName: 'complete this trip',
                  );
                  expect(canProceed, isTrue);
                },
                child: const Text('Test Online'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Online'));
      await tester.pumpAndSettle();

      expect(find.text('Internet Connection Required'), findsNothing);
    });

    testWidgets('blocks action and displays floating alert when offline', (tester) async {
      final fakeService = FakeConnectivityService(online: false);
      final guard = ConnectivityGuard(fakeService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final canProceed = await guard.checkOnlineOrNotify(
                    context,
                    actionName: 'complete this trip',
                    customMessage: 'You need to connect to the internet to complete this trip.',
                  );
                  expect(canProceed, isFalse);
                },
                child: const Text('Test Offline'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Offline'));
      await tester.pump();

      expect(find.text('Internet Connection Required'), findsOneWidget);
      expect(find.text('You need to connect to the internet to complete this trip.'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}
