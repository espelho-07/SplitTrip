import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/errors/app_error.dart';
import 'package:kith_app/core/errors/error_mapper.dart';
import 'package:kith_app/core/errors/operation_result.dart';
import 'package:kith_app/core/network/api_exceptions.dart';
import 'package:kith_app/core/utils/error_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Error Handling Architecture & User Activity Mapping Suite', () {
    test('1. Join Trip while offline maps to NetworkError with actionable retry prompt', () {
      final socketError = const SocketException('Failed host lookup: api.kith.app');
      final appError = ErrorMapper.map(
        socketError,
        activity: UserActivity.joinTrip,
        isSavedLocally: false,
      );

      expect(appError, isA<NetworkError>());
      expect(appError.userTitle, equals("You're offline"));
      expect(appError.userMessage, contains("An internet connection is required to verify and join this trip"));
      expect(appError.actionLabel, equals("Retry Join"));
      expect(appError.isSavedLocally, isFalse);
      expect(appError.isReachedServer, isFalse);
      expect(appError.isRetrySafe, isTrue);
      expect(appError.isUserActionRequired, isTrue);
    });

    test('2. Add Expense while offline maps to SynchronizationError with local save confirmation', () {
      final socketError = const SocketException('Connection refused');
      final appError = ErrorMapper.map(
        socketError,
        activity: UserActivity.addExpense,
        isSavedLocally: true,
      );

      expect(appError, isA<SynchronizationError>());
      expect(appError.userTitle, equals("Saved on device"));
      expect(appError.userMessage, contains("Your changes were saved locally"));
      expect(appError.isSavedLocally, isTrue);
      expect(appError.isReachedServer, isFalse);
      expect(appError.isRetrySafe, isTrue);
      expect(appError.isUserActionRequired, isFalse);
    });

    test('3. Record Payment interrupted by network drop maps to UnknownOutcomeError', () {
      final timeout = TimeoutException('Request timed out after 25s');
      final appError = ErrorMapper.map(
        timeout,
        activity: UserActivity.recordPayment,
        isSavedLocally: true,
      );

      expect(appError, isA<UnknownOutcomeError>());
      expect(appError.userTitle, equals("Checking payment status"));
      expect(appError.userMessage, contains("Network connection was interrupted while recording payment"));
      expect(appError.isOutcomeUnknown, isTrue);
      expect(appError.isSavedLocally, isTrue);
      expect(appError.isRetrySafe, isTrue);
    });

    test('4. Session expiration (401) maps to AuthenticationError with Sign In action', () {
      const unauthorized = UnauthorizedException();
      final appError = ErrorMapper.map(
        unauthorized,
        activity: UserActivity.addExpense,
        isSavedLocally: true,
      );

      expect(appError, isA<AuthenticationError>());
      expect(appError.userTitle, equals("Session expired"));
      expect(appError.actionLabel, equals("Sign In"));
      expect(appError.isSavedLocally, isTrue);
      expect(appError.isRetrySafe, isFalse);
      expect(appError.isUserActionRequired, isTrue);
    });

    test('5. Non-member trip access (403) maps to AuthorizationError', () {
      const forbidden = ForbiddenException();
      final appError = ErrorMapper.map(
        forbidden,
        activity: UserActivity.createTrip,
        isSavedLocally: false,
      );

      expect(appError, isA<AuthorizationError>());
      expect(appError.userTitle, equals("Access unavailable"));
      expect(appError.isReachedServer, isTrue);
      expect(appError.isRetrySafe, isFalse);
      expect(appError.isUserActionRequired, isTrue);
    });

    test('6. Concurrent edit conflict (409) maps to ConflictError with review guidance', () {
      const conflict = ConflictException(message: 'Stale revision: expected 4 but found 5');
      final appError = ErrorMapper.map(
        conflict,
        activity: UserActivity.editExpense,
        isSavedLocally: true,
      );

      expect(appError, isA<ConflictError>());
      expect(appError.userTitle, equals("Update conflict detected"));
      expect(appError.actionLabel, equals("Review Latest"));
      expect(appError.isSavedLocally, isTrue);
      expect(appError.isReachedServer, isTrue);
    });

    test('7. OperationResult lifecycle states distinguish synced, savedLocally, and failure', () {
      final syncedResult = OperationResult<String>.synced('exp_100');
      expect(syncedResult.isSuccess, isTrue);
      expect(syncedResult.isSynced, isTrue);
      expect(syncedResult.isSavedLocally, isTrue);
      expect(syncedResult.syncStatus, equals(SyncStateStatus.synced));
      expect(syncedResult.displayMessage, contains('synced to cloud'));

      final localResult = OperationResult<String>.savedLocally('exp_101');
      expect(localResult.isSuccess, isTrue);
      expect(localResult.isSynced, isFalse);
      expect(localResult.isSavedLocally, isTrue);
      expect(localResult.syncStatus, equals(SyncStateStatus.pending));
      expect(localResult.displayMessage, contains('Saved locally'));

      final failedResult = OperationResult<String>.failure(
        const DatabaseError(),
      );
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.isSavedLocally, isFalse);
      expect(failedResult.syncStatus, equals(SyncStateStatus.failed));
    });

    test('8. KithErrorFormatter delegates seamlessly to ErrorMapper preserving backwards compatibility', () {
      final socketError = const SocketException('Host lookup failed');
      final formattedJoin = KithErrorFormatter.format(socketError, context: 'join');
      expect(formattedJoin, contains("You're offline"));

      final appError = KithErrorFormatter.mapToApplicationError(
        socketError,
        activity: UserActivity.joinTrip,
      );
      expect(appError, isA<NetworkError>());
      expect(appError.userTitle, equals("You're offline"));
    });
  });
}
