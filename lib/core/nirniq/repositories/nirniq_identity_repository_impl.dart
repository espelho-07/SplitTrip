import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/nirniq_identity.dart';
import 'i_nirniq_identity_repository.dart';

/// Concrete implementation of [INirniqIdentityRepository] backed by Android Keystore
/// via [FlutterSecureStorage].
///
/// Invariants:
/// - Stores active NirniqIdentity encrypted at rest.
/// - Never exposes credentials or tokens.
/// - Supports hermetic dependency injection for unit testing.
class NirniqIdentityRepositoryImpl implements INirniqIdentityRepository {
  static const String _activeIdentityKey = 'nirniq_active_canonical_identity';
  static const String _identityPrefix = 'nirniq_identity_';

  final FlutterSecureStorage _storage;

  NirniqIdentityRepositoryImpl({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: false,
              ),
            );

  @override
  Future<NirniqIdentity?> findById(String nirniqId) async {
    try {
      final raw = await _storage.read(key: '$_identityPrefix$nirniqId');
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
        return NirniqIdentity.fromJson(json);
      }

      // Check active identity fallback
      final activeRaw = await _storage.read(key: _activeIdentityKey);
      if (activeRaw != null && activeRaw.isNotEmpty) {
        final Map<String, dynamic> activeJson = jsonDecode(activeRaw) as Map<String, dynamic>;
        final active = NirniqIdentity.fromJson(activeJson);
        if (active.nirniqId == nirniqId) return active;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<NirniqIdentity?> findByGoogleSubject(String googleSubject) async {
    try {
      final active = await getActiveIdentity();
      if (active != null && active.googleSubject == googleSubject) {
        return active;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<bool> existsForGoogleSubject(String googleSubject) async {
    final match = await findByGoogleSubject(googleSubject);
    return match != null;
  }

  @override
  Future<void> save(NirniqIdentity identity) async {
    final raw = jsonEncode(identity.toJson());
    await Future.wait([
      _storage.write(key: '$_identityPrefix${identity.nirniqId}', value: raw),
      _storage.write(key: _activeIdentityKey, value: raw),
    ]);
  }

  @override
  Future<NirniqIdentity?> getActiveIdentity() async {
    try {
      final raw = await _storage.read(key: _activeIdentityKey);
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return NirniqIdentity.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String nirniqId) async {
    final active = await getActiveIdentity();
    await _storage.delete(key: '$_identityPrefix$nirniqId');
    if (active?.nirniqId == nirniqId) {
      await _storage.delete(key: _activeIdentityKey);
    }
  }

  /// Clears all stored Nirniq identity records from secure storage.
  Future<void> clearAll() async {
    final active = await getActiveIdentity();
    if (active != null) {
      await _storage.delete(key: '$_identityPrefix${active.nirniqId}');
    }
    await _storage.delete(key: _activeIdentityKey);
  }
}
