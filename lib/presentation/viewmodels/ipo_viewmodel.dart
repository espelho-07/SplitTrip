import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/ipo_repository.dart';
import '../../domain/models/ipo/ipo.dart';
import '../../domain/models/ipo/ipo_account.dart';
import '../../domain/models/ipo/ipo_application.dart';
import '../../domain/services/notification_service.dart';

class IpoViewModel extends ChangeNotifier {
  final IpoRepository ipoRepo;
  final NotificationService? notificationService;

  List<Ipo> _ipos = [];
  List<IpoApplication> _applications = [];
  bool _isLoading = false;
  String _selectedTab = 'open'; // 'open', 'upcoming', 'closed', 'my_ipos', 'listed'
  IpoMarketType? _selectedMarketFilter; // null for All
  String _searchQuery = '';

  IpoViewModel({
    required this.ipoRepo,
    this.notificationService,
  }) {
    _loadFromCache();
  }

  List<IpoAccount> _accounts = [];

  List<IpoAccount> get accounts => _accounts;

  void _loadFromCache() {
    _ipos = ipoRepo.getCachedIpos();
    _applications = ipoRepo.getCachedApplications();
    _accounts = ipoRepo.getIpoAccounts();
  }

  List<Ipo> get ipos => _ipos;
  List<IpoApplication> get applications => _applications;
  bool get isLoading => _isLoading;
  String get selectedTab => _selectedTab;
  IpoMarketType? get selectedMarketFilter => _selectedMarketFilter;
  String get searchQuery => _searchQuery;
  DateTime? get lastUpdated => ipoRepo.getLastUpdated();

  // --- Filtered Listings (Uses dynamic status) ---
  List<Ipo> get filteredIpos {
    var list = _ipos;

    // Filter by Tab
    switch (_selectedTab) {
      case 'open':
        list = list.where((i) => i.dynamicStatus == IpoStatus.open).toList();
        break;
      case 'upcoming':
        list = list.where((i) => i.dynamicStatus == IpoStatus.upcoming).toList();
        break;
      case 'closed':
        list = list.where((i) => i.dynamicStatus == IpoStatus.closed || i.dynamicStatus == IpoStatus.allotmentOut).toList();
        break;
      case 'my_ipos':
        final appliedIpoIds = _applications.map((a) => a.ipoId).toSet();
        list = list.where((i) => i.isTracked || appliedIpoIds.contains(i.id)).toList();
        break;
      case 'listed':
        list = list.where((i) => i.dynamicStatus == IpoStatus.listed).toList();
        break;
    }

    // Filter by Market (Mainboard / SME)
    if (_selectedMarketFilter != null) {
      list = list.where((i) => i.marketType == _selectedMarketFilter).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) {
        return i.name.toLowerCase().contains(q) ||
            i.companyName.toLowerCase().contains(q) ||
            i.symbol.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  // --- Dynamic Counts ---
  int get openCount => _ipos.where((i) => i.dynamicStatus == IpoStatus.open).length;
  int get upcomingCount => _ipos.where((i) => i.dynamicStatus == IpoStatus.upcoming).length;
  int get closedCount => _ipos.where((i) => i.dynamicStatus == IpoStatus.closed || i.dynamicStatus == IpoStatus.allotmentOut).length;
  int get myIposCount {
    final appliedIds = _applications.map((a) => a.ipoId).toSet();
    return _ipos.where((i) => i.isTracked || appliedIds.contains(i.id)).length;
  }
  int get listedCount => _ipos.where((i) => i.dynamicStatus == IpoStatus.listed).length;

  // --- My IPOs Summary Metrics ---
  int get totalAppliedPaise {
    return _applications.fold<int>(0, (sum, a) => sum + a.applicationAmountInPaise);
  }

  int get totalInvestedPaise {
    return _applications.fold<int>(0, (sum, a) => sum + (a.actualInvestedAmountInPaise ?? 0));
  }

  int get totalReleasedPaise {
    return _applications.fold<int>(0, (sum, a) => sum + (a.releasedAmountInPaise ?? 0));
  }

  int get totalBlockedPaise {
    return _applications.where((a) {
      return a.status == IpoApplicationStatus.applied || a.status == IpoApplicationStatus.fundsBlocked;
    }).fold<int>(0, (sum, a) => sum + a.applicationAmountInPaise);
  }

  /// Calculates total unrealized P&L in Paise for allotted/listed IPOs
  int get totalUnrealizedPnlPaise {
    int pnl = 0;
    for (final app in _applications) {
      if (app.allottedShares != null && app.allottedShares! > 0) {
        final ipo = getIpoById(app.ipoId);
        final cmp = ipo?.currentPrice ?? ipo?.listingPrice;
        if (cmp != null && cmp > 0) {
          final issuePrice = ipo?.issuePrice ?? app.bidPriceInRupees;
          final diffPerShare = cmp - issuePrice;
          pnl += diffPerShare * app.allottedShares! * 100;
        }
      }
    }
    return pnl;
  }

  // --- Account-level Aggregations & Smart Payment Calculations ---
  Map<String, dynamic> getAccountMetrics(String accountId) {
    final summary = ipoRepo.getAccountFinancialSummary(accountId);
    final accountApps = ipoRepo.getApplicationsForAccount(accountId);

    return {
      'applicationCount': accountApps.length,
      'totalAppliedPaise': summary['totalAppliedPaise'] ?? 0,
      'totalPaidPaise': summary['totalPaidPaise'] ?? 0,
      'totalPendingPaise': summary['totalPendingPaise'] ?? 0,
      'totalBlockedPaise': summary['moneyBlockedPaise'] ?? 0,
      'totalReleasedPaise': summary['moneyReleasedPaise'] ?? 0,
      'totalInvestedPaise': summary['moneyInvestedPaise'] ?? 0,
      'availableBalancePaise': summary['availableBalancePaise'] ?? 0,
      'applications': accountApps,
    };
  }

  /// Checks if an account has eligible reusable credit from released/refunded non-allotments
  int getAccountAvailableCreditPaise(String accountId) {
    return ipoRepo.getAccountAvailableBalance(accountId);
  }

  // --- Actions ---
  Future<void> loadData({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    _ipos = await ipoRepo.getIpos(forceRefresh: forceRefresh);
    _applications = ipoRepo.getCachedApplications();
    _accounts = ipoRepo.getIpoAccounts();

    _isLoading = false;
    notifyListeners();

    // Background: sync allotment statuses from server for pending applications
    if (_applications.isNotEmpty) {
      final userId = _applications.first.userId;
      unawaited(_syncAllotmentsAndRefresh(userId));
    }

    // Check and trigger notifications for milestone reminders
    if (notificationService != null && _ipos.isNotEmpty) {
      await notificationService!.checkAndDispatchIpoReminders(
        ipos: _ipos,
        applications: _applications,
      );
    }
  }

  Future<void> _syncAllotmentsAndRefresh(String userId) async {
    try {
      await ipoRepo.syncAllotments(userId);
      _applications = ipoRepo.getCachedApplications();
      notifyListeners();
    } catch (_) {}
  }

  /// Manually triggers on-demand allotment check for a single application
  Future<void> checkAllotmentNow(String applicationId) async {
    final result = await ipoRepo.checkAllotmentNow(applicationId);
    if (result != null) {
      _applications = ipoRepo.getCachedApplications();
      notifyListeners();

      if (notificationService != null) {
        final updated = _applications.firstWhere((a) => a.id == applicationId, orElse: () => result);
        if (updated.status != IpoApplicationStatus.applied && updated.status != IpoApplicationStatus.fundsBlocked) {
          await notificationService!.notifyIpoApplicationUpdated(
            ipoId: updated.ipoId,
            ipoName: updated.ipoName,
            statusDisplayName: '${updated.accountName}: ${updated.status.displayName}',
            applicationId: applicationId,
          );
        }
      }
    }
  }

  Future<IpoAccount> createAccount({
    required String displayName,
    String? rawPan,
    String? accountHolderName,
    String? upiId,
  }) async {
    final newAcc = IpoAccount.create(
      displayName: displayName,
      rawPan: rawPan,
      accountHolderName: accountHolderName,
      upiId: upiId,
    );
    final saved = await ipoRepo.saveIpoAccount(newAcc);
    _accounts = ipoRepo.getIpoAccounts();
    notifyListeners();
    return saved;
  }

  Future<void> deleteAccount(String accountId) async {
    await ipoRepo.deleteIpoAccount(accountId);
    _accounts = ipoRepo.getIpoAccounts();
    notifyListeners();
  }

  void setTab(String tab) {
    if (_selectedTab != tab) {
      _selectedTab = tab;
      notifyListeners();
    }
  }

  void setMarketFilter(IpoMarketType? type) {
    _selectedMarketFilter = type;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Ipo? getIpoById(String id) => ipoRepo.getIpoById(id);

  IpoApplication? getApplicationForIpo(String ipoId) => ipoRepo.getApplicationForIpo(ipoId);

  List<IpoApplication> getAllApplicationsForIpo(String ipoId) => ipoRepo.getAllApplicationsForIpo(ipoId);

  Future<void> toggleTrackIpo(String ipoId) async {
    final ipo = getIpoById(ipoId);
    if (ipo == null) return;
    final newTracked = !ipo.isTracked;
    await ipoRepo.toggleTrackIpo(ipoId, newTracked);
    _ipos = ipoRepo.getCachedIpos();
    notifyListeners();
  }

  Future<List<IpoApplication>> recordMultipleApplications(List<IpoApplication> applications) async {
    final savedList = await ipoRepo.recordApplications(applications);
    _applications = ipoRepo.getCachedApplications();
    notifyListeners();

    if (notificationService != null && savedList.isNotEmpty) {
      for (final app in savedList) {
        await notificationService!.notifyIpoApplicationUpdated(
          ipoId: app.ipoId,
          ipoName: app.ipoName,
          statusDisplayName: '${app.accountName}: ${app.status.displayName}',
          applicationId: app.id,
        );
      }
    }

    return savedList;
  }

  Future<IpoApplication> recordApplication(IpoApplication application) async {
    final saved = await ipoRepo.recordApplication(application);
    _applications = ipoRepo.getCachedApplications();
    notifyListeners();

    // Notify user of application tracking
    if (notificationService != null) {
      await notificationService!.notifyIpoApplicationUpdated(
        ipoId: saved.ipoId,
        ipoName: saved.ipoName,
        statusDisplayName: saved.status.displayName,
        applicationId: saved.id,
      );
    }

    return saved;
  }

  Future<void> updateAllotment({
    required String applicationId,
    required IpoApplicationStatus status,
    int? allottedLots,
    int? issuePriceInRupees,
    String? notes,
  }) async {
    await ipoRepo.updateAllotment(
      applicationId: applicationId,
      status: status,
      allottedLots: allottedLots,
      issuePriceInRupees: issuePriceInRupees,
      notes: notes,
    );
    _applications = ipoRepo.getCachedApplications();
    notifyListeners();

    final app = _applications.firstWhere((a) => a.id == applicationId, orElse: () => _applications.first);
    if (notificationService != null) {
      await notificationService!.notifyIpoApplicationUpdated(
        ipoId: app.ipoId,
        ipoName: app.ipoName,
        statusDisplayName: status.displayName,
        applicationId: applicationId,
      );
    }
  }

  Future<void> recordPayment({
    required String applicationId,
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    await ipoRepo.recordIpoPayment(
      applicationId: applicationId,
      amountInPaise: amountInPaise,
      note: note,
      date: date,
    );
    _applications = ipoRepo.getCachedApplications();
    notifyListeners();
  }

  Future<void> deleteApplication(String applicationId) async {
    await ipoRepo.deleteApplication(applicationId);
    _applications = ipoRepo.getCachedApplications();
    notifyListeners();
  }
}

