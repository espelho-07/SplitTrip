import '../models/nirniq_identity.dart';

/// Abstract repository interface for Nirniq identity operations.
///
/// [PHASE 1 — INTERFACE ONLY]
/// No implementation exists yet. This interface defines the contract
/// that future implementations will fulfill.
/// Gate 1 (Supabase project creation) must be approved before
/// any real implementation is written.
abstract interface class INirniqIdentityRepository {
  /// Look up an existing Nirniq identity by its canonical ID.
  /// Returns null if not found.
  Future<NirniqIdentity?> findById(String nirniqId);

  /// Look up a Nirniq identity by its linked Google subject ID.
  /// Returns null if no such identity exists.
  Future<NirniqIdentity?> findByGoogleSubject(String googleSubject);

  /// Check whether a Nirniq identity exists for the given Google subject.
  Future<bool> existsForGoogleSubject(String googleSubject);
}
