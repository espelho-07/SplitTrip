import 'package:uuid/uuid.dart';
import 'local_storage_service.dart';

enum MutationType {
  createTrip,
  joinTrip,
  updateTripLifecycle,
  addExpense,
  deleteExpense,
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
}

/// Offline-first synchronization queue service.
/// Enqueues user mutations when offline and processes them when connectivity is restored.
class SyncService {
  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();

  SyncService(this._storage);

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
}
