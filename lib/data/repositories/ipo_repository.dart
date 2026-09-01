import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/ipo/ipo.dart';
import '../../domain/models/ipo/ipo_account.dart';
import '../../domain/models/ipo/ipo_application.dart';
import '../../domain/models/personal_debt.dart';
import '../services/ipo_data_provider.dart';
import '../services/local_storage_service.dart';
import 'personal_repository.dart';

class IpoRepository {
  final LocalStorageService storage;
  final IpoDataProvider dataProvider;
  final PersonalRepository personalRepo;

  List<Ipo> _cachedIpos = [];
  List<IpoApplication> _cachedApplications = [];

  IpoRepository({
    required this.storage,
    required this.dataProvider,
    required this.personalRepo,
  }) {
    _loadLocalCache();
  }

  void _loadLocalCache() {
    final rawIpos = storage.getSavedIpos();
    final trackedIds = storage.getTrackedIpoIds();
    if (rawIpos.isNotEmpty) {
      _cachedIpos = rawIpos.map((m) {
        final ipo = Ipo.fromJson(m);
        return ipo.copyWith(isTracked: trackedIds.contains(ipo.id));
      }).toList();
    }

    final rawApps = storage.getSavedIpoApplications();
    if (rawApps.isNotEmpty) {
      _cachedApplications = rawApps.map((m) => IpoApplication.fromJson(m)).toList();
    }
  }

  List<Ipo> getCachedIpos() => List.unmodifiable(_cachedIpos);

  List<IpoApplication> getCachedApplications() => List.unmodifiable(_cachedApplications);

  DateTime? getLastUpdated() => storage.getIposLastUpdated();

  /// Fetches IPO list from provider with local cache fallback
  Future<List<Ipo>> getIpos({bool forceRefresh = false}) async {
    final lastUpdated = storage.getIposLastUpdated();
    final isStale = lastUpdated == null || DateTime.now().difference(lastUpdated) > const Duration(minutes: 15);

    if (!forceRefresh && _cachedIpos.isNotEmpty && !isStale) {
      return _cachedIpos;
    }

    try {
      final freshIpos = await dataProvider.fetchIpos();
      final trackedIds = storage.getTrackedIpoIds();

      if (freshIpos.isNotEmpty) {
        _cachedIpos = freshIpos.map((ipo) {
          return ipo.copyWith(isTracked: trackedIds.contains(ipo.id));
        }).toList();

        await storage.saveIpos(_cachedIpos.map((i) => i.toJson()).toList());
        await storage.setIposLastUpdated(DateTime.now());
      }
      return _cachedIpos;
    } catch (e) {
      debugPrint('[IpoRepository] Error fetching fresh IPOs, using cached: $e');
      return _cachedIpos;
    }
  }

  Ipo? getIpoById(String id) {
    return _cachedIpos.cast<Ipo?>().firstWhere((i) => i?.id == id, orElse: () => null);
  }

  /// Returns the primary application for an IPO (for backward compatibility)
  IpoApplication? getApplicationForIpo(String ipoId) {
    return _cachedApplications
        .cast<IpoApplication?>()
        .firstWhere((a) => a?.ipoId == ipoId, orElse: () => null);
  }

  /// Returns all applications recorded for a specific IPO (across multiple accounts)
  List<IpoApplication> getAllApplicationsForIpo(String ipoId) {
    return _cachedApplications.where((a) => a.ipoId == ipoId).toList();
  }

  /// Returns all applications recorded for a specific application account
  List<IpoApplication> getApplicationsForAccount(String accountId) {
    if (accountId == 'me') {
      return _cachedApplications.where((a) => a.applicationAccountId == null || a.applicationAccountId == 'me').toList();
    }
    return _cachedApplications.where((a) => a.applicationAccountId == accountId).toList();
  }

  /// Reusable IPO Application Accounts
  List<IpoAccount> getIpoAccounts() {
    final raw = storage.getSavedIpoAccounts();
    return raw.map((json) => IpoAccount.fromJson(json)).toList();
  }

  Future<IpoAccount> saveIpoAccount(IpoAccount account) async {
    final accounts = getIpoAccounts();
    final idx = accounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) {
      accounts[idx] = account.copyWith(updatedAt: DateTime.now());
    } else {
      accounts.add(account);
    }
    await storage.saveIpoAccounts(accounts.map((a) => a.toJson()).toList());
    return account;
  }

  Future<void> deleteIpoAccount(String accountId) async {
    final accounts = getIpoAccounts()..removeWhere((a) => a.id == accountId);
    await storage.saveIpoAccounts(accounts.map((a) => a.toJson()).toList());
  }

  Future<void> toggleTrackIpo(String ipoId, bool isTracked) async {
    await storage.setIpoTracked(ipoId, isTracked);
    final idx = _cachedIpos.indexWhere((i) => i.id == ipoId);
    if (idx != -1) {
      _cachedIpos[idx] = _cachedIpos[idx].copyWith(isTracked: isTracked);
      await storage.saveIpos(_cachedIpos.map((i) => i.toJson()).toList());
    }
  }

  /// Records multiple IPO applications (e.g. Me, Brother, Friend) for an IPO
  Future<List<IpoApplication>> recordApplications(List<IpoApplication> applications) async {
    final saved = <IpoApplication>[];
    for (final app in applications) {
      final res = await recordApplication(app);
      saved.add(res);
    }
    return saved;
  }

  /// Records a single IPO application and links peer funding to the Person Ledger
  Future<IpoApplication> recordApplication(IpoApplication application) async {
    final updatedFundings = <IpoFunding>[];

    // For each external person contributor, record a real PersonalDebt in PersonalRepository
    for (final funding in application.fundings) {
      if (!funding.isSelf && funding.personName?.isNotEmpty == true && funding.amountInPaise > 0) {
        try {
          final debt = await personalRepo.createPersonalDebt(
            userId: application.userId,
            personName: funding.personName!,
            debtType: PersonalDebtType.borrowed, // Person gave user money for the IPO
            amountInPaise: funding.amountInPaise,
            description: '${application.ipoName} (${application.accountName} IPO Funding)',
            date: application.applicationDate,
          );
          updatedFundings.add(funding.copyWith(debtId: debt.id));
        } catch (e) {
          debugPrint('[IpoRepository] Failed to record peer debt for ${funding.personName}: $e');
          updatedFundings.add(funding);
        }
      } else {
        updatedFundings.add(funding);
      }
    }

    final finalApplication = application.copyWith(
      fundings: updatedFundings,
      updatedAt: DateTime.now(),
    );

    // Save in cache & local storage
    final existingIdx = _cachedApplications.indexWhere((a) => a.id == finalApplication.id);
    if (existingIdx != -1) {
      _cachedApplications[existingIdx] = finalApplication;
    } else {
      _cachedApplications.add(finalApplication);
    }

    await storage.saveIpoApplications(_cachedApplications.map((a) => a.toJson()).toList());
    return finalApplication;
  }

  /// Updates allotment outcome and calculates utilized/released funds
  Future<IpoApplication?> updateAllotment({
    required String applicationId,
    required IpoApplicationStatus status,
    int? allottedLots,
    int? issuePriceInRupees,
    String? notes,
  }) async {
    final idx = _cachedApplications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return null;

    final app = _cachedApplications[idx];
    final lots = allottedLots ?? (status == IpoApplicationStatus.allotted ? app.lotsApplied : 0);
    final shares = lots * app.lotSize;
    final price = issuePriceInRupees ?? app.bidPriceInRupees;

    final calc = IpoApplication.calculateAllotmentAmounts(
      applicationAmountPaise: app.applicationAmountInPaise,
      allottedLots: lots,
      lotSize: app.lotSize,
      issuePriceRupees: price,
    );

    final updated = app.copyWith(
      status: status,
      allottedLots: lots,
      allottedShares: shares,
      actualInvestedAmountInPaise: calc['investedPaise'],
      releasedAmountInPaise: calc['releasedPaise'],
      notes: notes ?? app.notes,
      updatedAt: DateTime.now(),
    );

    _cachedApplications[idx] = updated;
    await storage.saveIpoApplications(_cachedApplications.map((a) => a.toJson()).toList());
    return updated;
  }

  /// Deletes an IPO application and removes associated linked debts
  Future<void> deleteApplication(String applicationId) async {
    final idx = _cachedApplications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return;

    final app = _cachedApplications[idx];

    // Clean up created debt records for peer funders
    for (final funding in app.fundings) {
      if (funding.debtId != null) {
        try {
          await personalRepo.deletePersonalDebt(funding.debtId!);
        } catch (_) {}
      }
    }

    _cachedApplications.removeAt(idx);
    await storage.saveIpoApplications(_cachedApplications.map((a) => a.toJson()).toList());
  }

  /// Calculates available unutilized released funds for an account
  /// Released funds occur when an application is marked Not Allotted, Partially Allotted, or Refunded.
  int getAccountAvailableBalance(String accountId) {
    final apps = getApplicationsForAccount(accountId);
    int totalReleased = 0;
    for (final app in apps) {
      if (app.status == IpoApplicationStatus.notAllotted ||
          app.status == IpoApplicationStatus.refunded ||
          app.status == IpoApplicationStatus.partiallyAllotted) {
        totalReleased += (app.releasedAmountInPaise ?? (app.status == IpoApplicationStatus.notAllotted || app.status == IpoApplicationStatus.refunded ? app.applicationAmountInPaise : 0));
      }
    }
    return totalReleased;
  }

  /// Derives complete financial metrics for an account
  Map<String, int> getAccountFinancialSummary(String accountId) {
    final apps = getApplicationsForAccount(accountId);
    int totalApplied = 0;
    int totalPaid = 0;
    int totalPending = 0;
    int moneyBlocked = 0;
    int moneyReleased = 0;
    int moneyInvested = 0;

    for (final app in apps) {
      totalApplied += app.applicationAmountInPaise;
      totalPaid += (app.paidAmountInPaise ?? app.totalFundingAllocatedPaise);
      totalPending += app.effectiveRemainingPaise;

      switch (app.status) {
        case IpoApplicationStatus.applied:
        case IpoApplicationStatus.fundsBlocked:
        case IpoApplicationStatus.refundPending:
          moneyBlocked += app.applicationAmountInPaise;
          break;
        case IpoApplicationStatus.allotted:
        case IpoApplicationStatus.listed:
          moneyInvested += (app.actualInvestedAmountInPaise ?? app.applicationAmountInPaise);
          if (app.releasedAmountInPaise != null && app.releasedAmountInPaise! > 0) {
            moneyReleased += app.releasedAmountInPaise!;
          }
          break;
        case IpoApplicationStatus.partiallyAllotted:
          moneyInvested += (app.actualInvestedAmountInPaise ?? 0);
          moneyReleased += (app.releasedAmountInPaise ?? (app.applicationAmountInPaise - (app.actualInvestedAmountInPaise ?? 0)));
          break;
        case IpoApplicationStatus.notAllotted:
        case IpoApplicationStatus.refunded:
          moneyReleased += (app.releasedAmountInPaise ?? app.applicationAmountInPaise);
          break;
      }
    }

    return {
      'totalAppliedPaise': totalApplied,
      'totalPaidPaise': totalPaid,
      'totalPendingPaise': totalPending,
      'moneyBlockedPaise': moneyBlocked,
      'moneyReleasedPaise': moneyReleased,
      'moneyInvestedPaise': moneyInvested,
      'availableBalancePaise': moneyReleased,
    };
  }

  /// Records a canonical payment against an IPO application and reconciles Person Ledger
  Future<IpoApplication?> recordIpoPayment({
    required String applicationId,
    required int amountInPaise,
    String? note,
    DateTime? date,
  }) async {
    final idx = _cachedApplications.indexWhere((a) => a.id == applicationId);
    if (idx == -1 || amountInPaise <= 0) return null;

    final app = _cachedApplications[idx];
    final currentPaid = app.paidAmountInPaise ?? app.totalFundingAllocatedPaise;
    final newPaid = currentPaid + amountInPaise;
    final newRemaining = (app.applicationAmountInPaise - newPaid).clamp(0, app.applicationAmountInPaise);

    // If there is an associated person / peer funding, record payment in PersonalDebt ledger
    for (final funding in app.fundings) {
      if (!funding.isSelf && funding.personName?.isNotEmpty == true) {
        try {
          await personalRepo.createPersonalDebt(
            userId: app.userId,
            personName: funding.personName!,
            debtType: PersonalDebtType.lent, // Person repayment recorded
            amountInPaise: amountInPaise,
            description: '${app.ipoName} (${app.accountName} IPO Payment Received)',
            date: date ?? DateTime.now(),
          );
        } catch (e) {
          debugPrint('[IpoRepository] Error updating person ledger for payment: $e');
        }
      }
    }

    final updated = app.copyWith(
      paidAmountInPaise: newPaid,
      remainingAmountInPaise: newRemaining,
      updatedAt: DateTime.now(),
    );

    _cachedApplications[idx] = updated;
    await storage.saveIpoApplications(_cachedApplications.map((a) => a.toJson()).toList());
    return updated;
  }
}
