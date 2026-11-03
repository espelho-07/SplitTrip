import 'package:flutter/material.dart';
import '../../../data/services/admin/admin_audit_service.dart';
import '../../../data/services/admin/admin_exceptions.dart';
import '../../../data/services/admin/admin_user_service.dart';
import '../../../domain/models/admin/admin_models.dart';

enum UserFilterType { all, registered, guest, suspended }

/// ViewModel driving User Management, search, pagination, and suspension workflows.
class AdminUsersViewModel extends ChangeNotifier {
  final AdminUserService userService;
  final AdminAuditService auditService;

  AdminUsersViewModel({
    required this.userService,
    required this.auditService,
  });

  List<ManagedUser> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  UserFilterType _activeFilter = UserFilterType.all;
  int _offset = 0;
  static const int _pageSize = 25;
  bool _hasMore = true;

  List<ManagedUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  UserFilterType get activeFilter => _activeFilter;
  bool get hasMore => _hasMore;

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _offset = 0;
    fetchUsers(reset: true);
  }

  void setFilter(UserFilterType filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    _offset = 0;
    fetchUsers(reset: true);
  }

  /// Fetches users from the backend applying active search and filtering.
  Future<void> fetchUsers({bool reset = false}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
      _users = [];
    }

    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool? isGuest;
      bool? isSuspended;

      switch (_activeFilter) {
        case UserFilterType.all:
          break;
        case UserFilterType.registered:
          isGuest = false;
          break;
        case UserFilterType.guest:
          isGuest = true;
          break;
        case UserFilterType.suspended:
          isSuspended = true;
          break;
      }

      final fetched = await userService.fetchUsers(
        limit: _pageSize,
        offset: _offset,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        isGuestFilter: isGuest,
        isSuspendedFilter: isSuspended,
      );

      if (fetched.length < _pageSize) {
        _hasMore = false;
      }

      _users.addAll(fetched);
      _offset += fetched.length;
    } on AdminBackendUnavailableException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load user records: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Suspends a user account and appends an immutable audit log entry.
  Future<bool> suspendUser({
    required ManagedUser user,
    required String reason,
    required AdminUser currentAdmin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Atomic mutation and audit logging performed on server via kith_admin_suspend_user RPC
      await userService.suspendUser(userId: user.id, reason: reason);

      // Update local state reactively
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = user.copyWith(
          status: UserAccountStatus.suspended,
          suspendedAt: DateTime.now(),
          suspensionReason: reason,
        );
      }
      return true;
    } on AdminException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to suspend user: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Unsuspends a user account and logs the administrative action.
  Future<bool> unsuspendUser({
    required ManagedUser user,
    required AdminUser currentAdmin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Atomic unsuspension and audit logging performed on server via kith_admin_unsuspend_user RPC
      await userService.unsuspendUser(userId: user.id);

      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = user.copyWith(
          status: UserAccountStatus.active,
          suspendedAt: null,
          suspensionReason: null,
        );
      }
      return true;
    } on AdminException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to unsuspend user: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}
