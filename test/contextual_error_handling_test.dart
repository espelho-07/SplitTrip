import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/network/api_client.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/core/utils/error_formatter.dart';
import 'package:kith_app/data/repositories/trip_repository.dart';
import 'package:kith_app/data/services/local_storage_service.dart';
import 'package:kith_app/data/services/sync_service.dart';
import 'package:kith_app/domain/models/guest_user.dart';
import 'package:kith_app/presentation/viewmodels/join_trip_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingOfflineApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
  }

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    throw const NetworkException(message: 'Unable to reach server. Operating in offline mode.');
  }
}

class NotFoundApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    throw const NotFoundException(message: 'Trip not found');
  }

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    throw const NotFoundException(message: 'Trip not found');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KithErrorFormatter Contextual Formatting Suite', () {
    test('1. Offline / Network error in join context produces explicit offline prompt', () {
      final socketErr = const SocketException('Failed host lookup: api.kith.app');
      final formattedSocket = KithErrorFormatter.format(socketErr, context: 'join');
      expect(
        formattedSocket,
        "You're offline. Reconnect to the internet to see and join this trip.",
      );

      final networkErr = const NetworkException(message: 'Unable to reach server');
      final formattedNet = KithErrorFormatter.format(networkErr, context: 'join');
      expect(
        formattedNet,
        "You're offline. Reconnect to the internet to see and join this trip.",
      );

      final genericNetString = Exception('ClientException: Network connection failed');
      final formattedStr = KithErrorFormatter.format(genericNetString, context: 'join');
      expect(
        formattedStr,
        "You're offline. Reconnect to the internet to see and join this trip.",
      );
    });

    test('2. 404 / NotFound in join context produces clear nonexistent trip explanation', () {
      final notFoundApi = const NotFoundException(message: 'Trip not found');
      final formatted = KithErrorFormatter.format(notFoundApi, context: 'join');
      expect(
        formatted,
        'This trip does not exist. Check the code and try again.',
      );

      final notFoundCustom = const NotFoundException(message: 'The requested resource was not found.');
      final formattedCustom = KithErrorFormatter.format(notFoundCustom, context: 'join');
      expect(
        formattedCustom,
        'This trip does not exist. Check the code and try again.',
      );

      final notFoundStr = Exception('404 Not Found: trip not found');
      final formattedStr = KithErrorFormatter.format(notFoundStr, context: 'join');
      expect(
        formattedStr,
        'This trip does not exist. Check the code and try again.',
      );
    });

    test('3. General error context formats network, auth, validation, and conflict correctly', () {
      final netErr = const NetworkException(message: 'Socket timed out');
      expect(
        KithErrorFormatter.format(netErr),
        'Unable to connect to the server. Please check your internet connection.',
      );

      final authErr = const UnauthorizedException(message: 'Token expired');
      expect(
        KithErrorFormatter.format(authErr),
        'Session expired or invalid. Please sign in again.',
      );

      final forbidErr = const ForbiddenException(message: 'Access denied');
      expect(
        KithErrorFormatter.format(forbidErr),
        'You do not have permission to perform this action.',
      );

      final conflictErr = const ConflictException(message: 'You are already a member of this trip.');
      expect(
        KithErrorFormatter.format(conflictErr),
        'You are already a member of this trip.',
      );

      final rawApiString = 'ApiException [VALIDATION_ERROR] (400): Code must be 6 alphanumeric characters';
      expect(
        KithErrorFormatter.format(rawApiString),
        'Code must be 6 alphanumeric characters',
      );
    });
  });

  group('JoinTripViewModel Offline vs Not Found Suite', () {
    late LocalStorageService storage;
    late SyncService syncService;
    late GuestUser user;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      syncService = SyncService(storage);
      user = GuestUser(
        id: 'usr_test_error_vm',
        displayName: 'Test User',
        recoveryKey: 'KEY-1234-ABCD',
        anonymousToken: 'tok_error_vm',
        createdAt: DateTime.now(),
      );
    });

    test('4. Fetching trip preview while offline sets informative offline error, not 404', () async {
      final offlineClient = FailingOfflineApiClient();
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: offlineClient,
      );
      final joinVm = JoinTripViewModel(tripRepo: tripRepo);

      final result = await joinVm.fetchPreview('TRIP99');
      expect(result, isNull);
      expect(
        joinVm.errorMessage,
        "You're offline. Reconnect to the internet to see and join this trip.",
      );
    });

    test('5. Joining trip while offline sets informative offline error', () async {
      final offlineClient = FailingOfflineApiClient();
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: offlineClient,
      );
      final joinVm = JoinTripViewModel(tripRepo: tripRepo);

      final result = await joinVm.joinTrip(user, 'TRIP99');
      expect(result, isNull);
      expect(
        joinVm.errorMessage,
        "You're offline. Reconnect to the internet to see and join this trip.",
      );
    });

    test('6. Fetching nonexistent trip code returns clean not found message', () async {
      final notFoundClient = NotFoundApiClient();
      final tripRepo = TripRepository(
        storage: storage,
        syncService: syncService,
        apiClient: notFoundClient,
      );
      final joinVm = JoinTripViewModel(tripRepo: tripRepo);

      final result = await joinVm.fetchPreview('BAD999');
      expect(result, isNull);
      expect(
        joinVm.errorMessage,
        'This trip does not exist. Check the code and try again.',
      );
    });
  });
}
