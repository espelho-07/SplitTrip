import 'package:flutter/material.dart';
import '../../../data/services/admin/admin_audit_service.dart';
import '../../../data/services/admin/admin_exceptions.dart';
import '../../../domain/models/admin/admin_models.dart';

/// ViewModel driving the immutable audit ledger inspection view.
class AdminAuditLogsViewModel extends ChangeNotifier {
  final AdminAuditService auditService;

  AdminAuditLogsViewModel({required this.auditService});

  List<AdminAuditLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _actionFilter;
  String? _targetFilter;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;

  List<AdminAuditLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get actionFilter => _actionFilter;
  String? get targetFilter => _targetFilter;
  bool get hasMore => _hasMore;

  void setFilter({String? action, String? target}) {
    _actionFilter = action;
    _targetFilter = target;
    fetchLogs(reset: true);
  }

  /// Fetches audit logs from the immutable database ledger.
  Future<void> fetchLogs({bool reset = false}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
      _logs = [];
    }

    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await auditService.fetchAuditLogs(
        actionFilter: _actionFilter,
        targetTypeFilter: _targetFilter,
        limit: _pageSize,
        offset: _offset,
      );

      if (fetched.length < _pageSize) {
        _hasMore = false;
      }

      _logs.addAll(fetched);
      _offset += fetched.length;
    } on AdminBackendUnavailableException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load audit records: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
