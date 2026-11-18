import '../models/nirniq_identity.dart';

/// Abstract repository interface for Nirniq identity operations.
abstract interface class INirniqIdentityRepository {
  /// Look up an existing Nirniq identity by its canonical ID.
  /// Returns null if not found.
  Future<NirniqIdentity?> findById(String nirniqId);

  /// Look up a Nirniq identity by its linked Google subject ID.
  /// Returns null if no such identity exists.
  Future<NirniqIdentity?> findByGoogleSubject(String googleSubject);

  /// Check whether a Nirniq identity exists for the given Google subject.
  Future<bool> existsForGoogleSubject(String googleSubject);

  /// Persists a canonical [NirniqIdentity] to storage.
  Future<void> save(NirniqIdentity identity);

  /// Retrieves the active canonical identity from storage.
  Future<NirniqIdentity?> getActiveIdentity();

  /// Removes a stored identity from storage.
  Future<void> delete(String nirniqId);
}
