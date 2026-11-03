import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../domain/models/admin/admin_models.dart';
import 'admin_exceptions.dart';

/// Central authentication and server-side role resolution service for administrators.
class AdminService {
  AdminUser? _currentAdmin;
  bool _isLoading = false;

  AdminUser? get currentAdmin => _currentAdmin;
  bool get isAuthenticatedAdmin => _currentAdmin != null;
  bool get isLoading => _isLoading;

  /// Check whether the current user has the requested [permission].
  bool hasPermission(AdminPermission permission) {
    if (_currentAdmin == null) return false;
    return _currentAdmin!.hasPermission(permission);
  }

  /// Verifies caller's administrative status server-side against the `admin_roles` table.
  /// Fails closed: unauthenticated or non-admin users receive null.
  Future<AdminUser?> resolveCurrentAdminRole() async {
    _isLoading = true;
    try {
      if (!SupabaseConfig.isConfigured) {
        _currentAdmin = null;
        return null;
      }

      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = session?.user;

      if (user == null) {
        _currentAdmin = null;
        return null;
      }

      // Query server-side admin_roles table
      final response = await client
          .from('admin_roles')
          .select('role, granted_at, granted_by')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null || response['role'] == null) {
        _currentAdmin = null;
        return null;
      }

      final role = AdminRole.fromString(response['role'] as String?);
      final grantedAtStr = response['granted_at'] as String?;
      final grantedAt = grantedAtStr != null ? DateTime.tryParse(grantedAtStr) ?? DateTime.now() : DateTime.now();

      _currentAdmin = AdminUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String? ??
            user.email?.split('@')[0] ??
            'Administrator',
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        role: role,
        grantedAt: grantedAt,
        grantedBy: response['granted_by'] as String?,
        lastActiveAt: DateTime.now(),
      );

      return _currentAdmin;
    } on PostgrestException catch (e) {
      debugPrint('[AdminService] PostgrestException resolving role: ${e.message} (code: ${e.code})');
      _currentAdmin = null;
      if (e.code == '42P01' || e.code == 'PGRST116') {
        throw const AdminBackendUnavailableException('admin_roles');
      }
      rethrow;
    } catch (e) {
      debugPrint('[AdminService] Unexpected error resolving admin role: $e');
      _currentAdmin = null;
      return null;
    } finally {
      _isLoading = false;
    }
  }

  /// Triggers Google Sign-In and verifies server-side admin authorization.
  Future<AdminUser> authenticateWithGoogle() async {
    _isLoading = true;
    try {
      final authResult = await GoogleAuthService.signIn();
      if (authResult == null) {
        throw const AdminUnauthorizedException('Google Sign-In was cancelled.');
      }

      final admin = await resolveCurrentAdminRole();
      if (admin == null) {
        // Sign out from Supabase immediately if not an authorized administrator
        await GoogleAuthService.signOut();
        throw AdminUnauthorizedException(
          'Access Denied: The account ${authResult.email} is not registered as an authorized administrator.',
        );
      }

      return admin;
    } finally {
      _isLoading = false;
    }
  }

  /// Revokes administrative session and signs out.
  Future<void> signOut() async {
    _currentAdmin = null;
    await GoogleAuthService.signOut();
  }

  /// Lists all registered administrative accounts.
  /// Requires [AdminPermission.manageAdminRoles] (Super Admin only).
  Future<List<AdminUser>> listAdmins() async {
    final client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;
    if (client == null) {
      throw const AdminBackendUnavailableException('admin_roles');
    }

    try {
      final response = await client
          .from('admin_roles')
          .select('user_id, role, granted_at, granted_by, users:user_id(email, display_name, avatar_url)')
          .order('granted_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows.map((row) {
        final r = row as Map<String, dynamic>;
        final userObj = r['users'] as Map<String, dynamic>? ?? {};
        final role = AdminRole.fromString(r['role'] as String?);
        final grantedAtStr = r['granted_at'] as String?;
        final grantedAt = grantedAtStr != null ? DateTime.tryParse(grantedAtStr) ?? DateTime.now() : DateTime.now();

        return AdminUser(
          id: r['user_id'] as String? ?? '',
          email: userObj['email'] as String? ?? '',
          displayName: userObj['display_name'] as String? ?? 'Administrator',
          avatarUrl: userObj['avatar_url'] as String?,
          role: role,
          grantedAt: grantedAt,
          grantedBy: r['granted_by'] as String?,
          lastActiveAt: DateTime.now(),
        );
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint('[AdminService] listAdmins error: ${e.message} (${e.code})');
      if (e.code == '42P01') {
        throw const AdminBackendUnavailableException('admin_roles');
      }
      rethrow;
    }
  }

  /// Grants or modifies an administrative role for a user.
  /// Strictly requires [AdminPermission.manageAdminRoles] (Super Admin).
  /// Executes atomically via server-side RPC [kith_set_admin_role] ensuring
  /// role mutation and audit log insertion occur in the same database transaction.
  Future<void> grantAdminRole({
    required String targetUserId,
    required AdminRole role,
  }) async {
    if (!hasPermission(AdminPermission.manageAdminRoles)) {
      throw const AdminUnauthorizedException('Only Super Administrators can assign or modify admin roles.');
    }

    final client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_set_admin_role',
        'Supabase client is not configured.',
      );
    }

    try {
      await client.rpc('kith_set_admin_role', params: {
        'p_target_user_id': targetUserId,
        'p_new_role': role.value,
      });
    } on PostgrestException catch (e) {
      debugPrint('[AdminService] grantAdminRole RPC error: ${e.message} (${e.code})');
      if (e.code == '42883' || e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'kith_set_admin_role',
          'Atomic role assignment RPC is pending migration 20261101000007.',
        );
      }
      rethrow;
    }
  }

  /// Revokes administrative access for a user.
  /// Cannot revoke the last remaining super_admin.
  /// Executes atomically via server-side RPC [kith_revoke_admin_role].
  Future<void> revokeAdminRole({required String targetUserId}) async {
    if (!hasPermission(AdminPermission.manageAdminRoles)) {
      throw const AdminUnauthorizedException('Only Super Administrators can revoke admin roles.');
    }

    if (targetUserId == _currentAdmin?.id) {
      throw const AdminValidationException('Administrators cannot revoke their own privileges.');
    }

    final client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_revoke_admin_role',
        'Supabase client is not configured.',
      );
    }

    try {
      await client.rpc('kith_revoke_admin_role', params: {
        'p_target_user_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      debugPrint('[AdminService] revokeAdminRole RPC error: ${e.message} (${e.code})');
      if (e.code == '42883' || e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'kith_revoke_admin_role',
          'Atomic role revocation RPC is pending migration 20261101000007.',
        );
      }
      rethrow;
    }
  }

  /// One-time bootstrap of the initial Super-Admin account.
  /// Requires caller to be already authenticated via verified Google OAuth.
  /// Strictly rejects client-supplied user IDs, emails, or reusable secrets.
  /// Enforces server-side identity verification, concurrency protection, and atomic permanent locking in PostgreSQL.
  Future<bool> bootstrapInitialSuperAdmin() async {
    final client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;
    if (client == null) {
      throw const AdminBackendUnavailableException(
        'kith_bootstrap_initial_super_admin',
        'Supabase client is not configured.',
      );
    }

    final session = client.auth.currentSession;
    final user = session?.user;
    if (user == null || user.id.isEmpty) {
      throw const AdminUnauthorizedException(
        'Authentication required: A verified Google OAuth session is strictly required to bootstrap initial Super-Admin.',
      );
    }

    try {
      final res = await client.rpc('kith_bootstrap_initial_super_admin');
      if (res is bool) return res;
      if (res is Map && res['success'] == true) return true;
      return false;
    } on PostgrestException catch (e) {
      debugPrint('[AdminService] bootstrapInitialSuperAdmin error: ${e.message} (${e.code})');
      if (e.code == '42883' || e.code == '42P01') {
        throw const AdminBackendUnavailableException(
          'kith_bootstrap_initial_super_admin',
          'Bootstrap RPC is pending migration 20261101000007.',
        );
      }
      rethrow;
    }
  }
}
