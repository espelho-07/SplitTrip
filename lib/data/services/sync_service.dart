import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import 'local_storage_service.dart';

enum MutationType {
  createTrip,
  joinTrip,
  updateTripLifecycle,
  addExpense,
  updateExpense,
  deleteExpense,
  createPersonalExpense,
  updatePersonalExpense,
  deletePersonalExpense,
  createPersonalDebt,
  recordPersonalRepayment,
  deletePersonalDebt,
  setPersonalBudget,
  createJourneyMoment,
  deleteJourneyMoment,
}

class SyncMutation {
  final String id;
  final MutationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  SyncMutation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncMutation.fromJson(Map<String, dynamic> json) => SyncMutation(
    id: json['id'] as String,
    type: MutationType.values.firstWhere((e) => e.name == json['type']),
    payload: json['payload'] as Map<String, dynamic>,
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );

  SyncMutation copyWith({int? retryCount}) => SyncMutation(
    id: id,
    type: type,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Offline-first synchronization queue service.
/// Enqueues user mutations when offline and processes them when connectivity is restored.
class SyncService {
  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();
  bool _isProcessing = false;

  SyncService(this._storage);

  bool get isProcessing => _isProcessing;
  int get pendingCount => getPendingMutations().length;

  List<SyncMutation> getPendingMutations() {
    final raw = _storage.getMutationQueue();
    return raw.map((json) => SyncMutation.fromJson(json)).toList();
  }

  Future<void> enqueueMutation(MutationType type, Map<String, dynamic> payload) async {
    final mutation = SyncMutation(
      id: _uuid.v4(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    final queue = getPendingMutations();
    queue.add(mutation);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
  }

  Future<void> removeMutation(String id) async {
    final queue = getPendingMutations();
    queue.removeWhere((m) => m.id == id);
    await _storage.saveMutationQueue(queue.map((m) => m.toJson()).toList());
  }

  /// Processes all pending offline mutations against the remote backend.
  Future<void> flushQueue(ApiClient apiClient) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final queue = getPendingMutations();
      for (final mutation in queue) {
        try {
          await _executeMutation(apiClient, mutation);
          await removeMutation(mutation.id);
        } on NetworkException catch (_) {
          // Break loop and retry later when connection returns
          break;
        } on ApiException catch (_) {
          // Remove unrecoverable client errors to prevent blocking the queue
          await removeMutation(mutation.id);
        } catch (_) {
          break;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeMutation(ApiClient apiClient, SyncMutation mutation) async {
    switch (mutation.type) {
      case MutationType.createTrip:
        await apiClient.post('/trips', body: mutation.payload);
        break;
      case MutationType.joinTrip:
        await apiClient.post('/trips/join', body: mutation.payload);
        break;
      case MutationType.updateTripLifecycle:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.patch('/trips/$tripId/lifecycle', body: mutation.payload);
        break;
      case MutationType.addExpense:
        final tripId = mutation.payload['tripId'] as String;
        await apiClient.post('/trips/$tripId/expenses', body: mutation.payload);
        break;
      case MutationType.updateExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = mutation.payload['id'] as String;
        await apiClient.put('/trips/$tripId/expenses/$expenseId', body: mutation.payload);
        break;
      case MutationType.deleteExpense:
        final tripId = mutation.payload['tripId'] as String;
        final expenseId = mutation.payload['expenseId'] as String;
        await apiClient.delete('/trips/$tripId/expenses/$expenseId');
        break;
      case MutationType.createPersonalExpense:
        await apiClient.post('/personal/expenses', body: mutation.payload);
        break;
      case MutationType.updatePersonalExpense:
        final id = mutation.payload['id'] as String;
        await apiClient.put('/personal/expenses/$id', body: mutation.payload);
        break;
      case MutationType.deletePersonalExpense:
        final id = mutation.payload['id'] as String;
        await apiClient.delete('/personal/expenses/$id');
        break;
      case MutationType.createPersonalDebt:
        await apiClient.post('/personal/debts', body: mutation.payload);
        break;
      case MutationType.recordPersonalRepayment:
        final debtId = mutation.payload['debtId'] as String;
        await apiClient.post('/personal/debts/$debtId/repayments', body: mutation.payload);
        break;
      case MutationType.deletePersonalDebt:
        final id = mutation.payload['id'] as String;
        await apiClient.delete('/personal/debts/$id');
        break;
      case MutationType.setPersonalBudget:
        await apiClient.put('/personal/budget', body: mutation.payload);
        break;
      case MutationType.createJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentPayload = mutation.payload['moment'] as Map<String, dynamic>;
        await apiClient.post('/trips/$tripId/moments', body: momentPayload);
        break;
      case MutationType.deleteJourneyMoment:
        final tripId = mutation.payload['tripId'] as String;
        final momentId = mutation.payload['momentId'] as String;
        await apiClient.delete('/trips/$tripId/moments/$momentId');
        break;
    }
  }
}
