import 'package:flutter/material.dart';
import '../../../data/services/admin/admin_exceptions.dart';
import '../../../data/services/admin/admin_service.dart';
import '../../../data/services/admin/analytics_service.dart';
import '../../../domain/models/admin/admin_models.dart';

enum AdminSection {
  overview('overview', 'Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
  users('users', 'Users', Icons.people_outline_rounded, Icons.people_rounded),
  feedback('feedback', 'Feedback', Icons.inbox_outlined, Icons.inbox_rounded),
  featureRequests('feature-requests', 'Feature Requests', Icons.how_to_vote_outlined, Icons.how_to_vote_rounded),
  analytics('analytics', 'Analytics', Icons.analytics_outlined, Icons.analytics_rounded),
  announcements('announcements', 'Announcements', Icons.campaign_outlined, Icons.campaign_rounded),
  auditLogs('audit-logs', 'Audit Logs', Icons.security_outlined, Icons.security_rounded),
  settings('settings', 'Admin Settings', Icons.settings_outlined, Icons.settings_rounded);

  final String routePath;
  final String label;
  final IconData outlineIcon;
  final IconData filledIcon;

  const AdminSection(this.routePath, this.label, this.outlineIcon, this.filledIcon);

  static AdminSection fromRoute(String? path) {
    if (path == null) return AdminSection.overview;
    final normalized = path.replaceAll('/admin', '').replaceAll('/', '').trim().toLowerCase();
    for (final s in AdminSection.values) {
      if (s.routePath == normalized) return s;
    }
    return AdminSection.overview;
  }
}

/// Primary ViewModel driving the Admin Control Center layout, role checks, and metric summaries.
class AdminDashboardViewModel extends ChangeNotifier {
  final AdminService adminService;
  final AnalyticsService analyticsService;

  AdminDashboardViewModel({
    required this.adminService,
    required this.analyticsService,
  });

  AdminSection _currentSection = AdminSection.overview;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBackendUnavailable = false;
  AnalyticsSummary? _summary;

  AdminSection get currentSection => _currentSection;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBackendUnavailable => _isBackendUnavailable;
  AnalyticsSummary? get summary => _summary;
  AdminUser? get currentAdmin => adminService.currentAdmin;
  bool get isAuthenticated => adminService.isAuthenticatedAdmin;

  void setSection(AdminSection section) {
    if (_currentSection == section) return;
    _currentSection = section;
    notifyListeners();
  }

  /// Checks if current administrator possesses permission for the requested action.
  bool can(AdminPermission permission) => adminService.hasPermission(permission);

  /// Initializes the dashboard, verifies admin role, and loads platform metrics.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    _isBackendUnavailable = false;
    notifyListeners();

    try {
      final admin = await adminService.resolveCurrentAdminRole();
      if (admin == null) {
        _errorMessage = 'Access Denied: Unauthenticated or non-administrative account.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await loadOverviewMetrics();
    } on AdminBackendUnavailableException catch (e) {
      _isBackendUnavailable = true;
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to initialize Admin Control Center: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads aggregated platform metrics for the Overview section.
  Future<void> loadOverviewMetrics() async {
    try {
      _summary = await analyticsService.fetchAnalyticsSummary();
      _isBackendUnavailable = false;
    } on AdminBackendUnavailableException catch (e) {
      _isBackendUnavailable = true;
      _errorMessage = e.message;
    } catch (e) {
      debugPrint('[AdminDashboardViewModel] Metrics load notice: $e');
    }
    notifyListeners();
  }

  /// Triggers Google OAuth sign-in to authenticate as administrator.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await adminService.authenticateWithGoogle();
      await loadOverviewMetrics();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AdminException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Authentication failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Logs out of administrative session.
  Future<void> signOut() async {
    await adminService.signOut();
    _summary = null;
    _currentSection = AdminSection.overview;
    notifyListeners();
  }
}
