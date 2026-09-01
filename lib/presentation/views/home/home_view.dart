import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/realtime_client.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/kith_widget_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/p2p_sync_service.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../../domain/services/notification_service.dart';
import '../../router/app_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../viewmodels/version_viewmodel.dart';
import '../personal/personal_home_tab.dart';
import '../ipo/ipo_home_view.dart';
import '../profile/profile_home_tab.dart';
import '../trip/trips_home_tab.dart';
import '../version/update_available_banner.dart';
import '../version/kith_update_popup_dialog.dart';
import '../payment/payment_verification_dialog.dart';
import 'widgets/dashboard_tab.dart';

class HomeView extends StatefulWidget {
  final int initialIndex;
  const HomeView({super.key, this.initialIndex = 0});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late int _currentIndex;
  bool _isRefreshing = false;
  StreamSubscription<RealtimeTripEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final storage = context.read<LocalStorageService>();
        if (!storage.hasRequestedInitialPermissions()) {
          await storage.setHasRequestedInitialPermissions(true);
          await PermissionService.requestInitialAppPermissions();
        }
        if (!mounted) return;
        final p2p = context.read<P2PSyncService>();
        await p2p.start();
      } catch (_) {}
      if (mounted) {
        _refreshAllData();
        _setupRealtimeListener();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    RealtimeClient? realtimeClient;
    try {
      realtimeClient = context.read<RealtimeClient>();
    } catch (_) {}

    _realtimeSub?.cancel();
    _realtimeSub = realtimeClient?.events.listen((event) {
      if (!mounted) return;
      final notifService = context.read<NotificationService>();
      final currentUserId = context.read<AuthViewModel>().currentUser?.id;
      if (currentUserId == null) return;

      // Helper: extract notification sub-map or top-level data
      Map<String, dynamic> notifData(RealtimeTripEvent e) {
        if (e.data['notification'] is Map<String, dynamic>) {
          return e.data['notification'] as Map<String, dynamic>;
        }
        return e.data;
      }

      // Helper: check if current user is the recipient of this notification
      bool isRecipient(Map<String, dynamic> data) {
        final rid = data['recipientUserId'] as String?;
        return rid != null && rid == currentUserId;
      }

      // Helper: check if current user is the payer (for confirm/dispute notifications)
      bool isPayer(Map<String, dynamic> data) {
        final pid = data['payerUserId'] as String? ?? data['fromUserId'] as String?;
        return pid != null && pid == currentUserId;
      }

      if (event.type == 'settlement_marked_paid' || event.type == 'settlement_recorded') {
        // Y (Receiver) receives notification that X marked payment as paid
        final nd = notifData(event);
        if (isRecipient(nd)) {
          final fromName = nd['payerName'] as String? ?? nd['fromName'] as String? ?? 'A member';
          final toName = nd['receiverName'] as String? ?? 'You';
          final amountPaise = nd['amountInPaise'] as int? ?? 0;
          final settlementId = nd['settlementId'] as String? ?? event.data['settlementId'] as String? ?? event.eventId;
          final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');

          // Store verification payload on receiver device
          final storage = context.read<LocalStorageService>();
          storage.addPaymentVerification({
            'id': 'pvr_$settlementId',
            'settlementId': settlementId,
            'tripId': event.tripId,
            'tripName': nd['tripName'] as String? ?? 'Trip',
            'payerMemberId': nd['payerMemberId'],
            'payerUserId': nd['payerUserId'],
            'payerName': fromName,
            'receiverMemberId': nd['recipientMemberId'],
            'receiverUserId': currentUserId,
            'receiverName': toName,
            'amountInPaise': amountPaise,
            'paymentMethod': 'Direct',
            'status': 'pending_verification',
            'markedAt': DateTime.now().toIso8601String(),
          });

          // Add in-app and system notification strictly for receiver (Rule 13, 14, 18)
          notifService.addNotification(
            title: 'Payment received',
            description: '$fromName says they paid you $formatted.',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}?settlementId=$settlementId',
            actionLabel: 'Verify Payment',
            idempotencyKey: '${settlementId}_marked_paid',
          );

          // Prompt the verification sheet in foreground
          Future.microtask(() {
            if (mounted) {
              PaymentVerificationManager.checkAndPrompt(context);
            }
          });
        }
      } else if (event.type == 'settlement_confirmed') {
        final storage = context.read<LocalStorageService>();
        // Update local settlement in storage immediately
        final settlementId = event.data['settlementId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['id'] as String? : null);
        final fromMemberId = event.data['fromMemberId'] as String? ??
            event.data['payerMemberId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['fromMemberId'] as String? : null);
        final toMemberId = event.data['toMemberId'] as String? ??
            event.data['receiverMemberId'] as String? ??
            (event.data['settlement'] is Map ? event.data['settlement']['toMemberId'] as String? : null);
        final amt = int.tryParse(event.data['amountInPaise']?.toString() ??
            (event.data['settlement'] is Map ? event.data['settlement']['amountInPaise']?.toString() ?? '0' : '0')) ?? 0;

        final saved = storage.getSavedTripSettlements(event.tripId);
        bool found = false;
        final nowStr = DateTime.now().toIso8601String();
        for (int i = 0; i < saved.length; i++) {
          final s = saved[i];
          final matchesId = settlementId != null && s['id'] == settlementId;
          final matchesPair = fromMemberId != null && toMemberId != null &&
              s['fromMemberId'] == fromMemberId && s['toMemberId'] == toMemberId;
          if (matchesId || matchesPair) {
            saved[i]['status'] = 'confirmed';
            saved[i]['isSettled'] = true;
            saved[i]['confirmedAt'] = nowStr;
            found = true;
          }
        }
        if (!found && settlementId != null) {
          saved.insert(0, {
            'id': settlementId,
            'tripId': event.tripId,
            'fromMemberId': fromMemberId,
            'toMemberId': toMemberId,
            'amountInPaise': amt,
            'status': 'confirmed',
            'isSettled': true,
            'confirmedAt': nowStr,
            'createdAt': nowStr,
          });
        }
        storage.saveTripSettlements(event.tripId, saved);

        final homeVm = context.read<HomeViewModel>();
        final personalVm = context.read<PersonalExpenseViewModel>();
        final currentUserId = context.read<AuthViewModel>().currentUser?.id;
        if (currentUserId != null) {
          homeVm.loadTrips(currentUserId);
          personalVm.loadData(currentUserId);
        }

        // X (payer) receives confirmation that Y acknowledged the payment
        final nd = notifData(event);
        if (isPayer(nd)) {
          final toName = nd['receiverName'] as String? ?? nd['toName'] as String? ?? 'your friend';
          final amountPaise = nd['amountInPaise'] as int? ?? 0;
          final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
          notifService.addNotification(
            title: 'Payment Confirmed ✅',
            description: '$toName confirmed receiving $formatted. Payment complete!',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}',
            actionLabel: 'View',
            idempotencyKey: '${event.data['settlementId'] ?? event.eventId}_confirmed',
          );
        }
      } else if (event.type == 'settlement_disputed') {
        // X (payer) receives dispute from Y
        final nd = notifData(event);
        if (isPayer(nd)) {
          final toName = nd['receiverName'] as String? ?? nd['toName'] as String? ?? 'your friend';
          notifService.addNotification(
            title: 'Payment Disputed ⚠️',
            description: '$toName raised an issue with your payment. Please review.',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}',
            actionLabel: 'View',
            idempotencyKey: '${event.data['settlementId'] ?? event.eventId}_disputed',
          );
        }
      } else if (event.type == 'payment_proof_submitted') {
        // Y (receiver) gets notified that X uploaded proof
        final nd = notifData(event);
        if (isRecipient(nd)) {
          final fromName = nd['payerName'] as String? ?? nd['fromName'] as String? ?? 'A member';
          notifService.addNotification(
            title: 'Payment Proof Uploaded 📎',
            description: '$fromName submitted payment proof. Review and confirm receipt.',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}',
            actionLabel: 'Review',
            idempotencyKey: '${event.data['settlementId'] ?? event.eventId}_proof',
          );
        }
      } else if (event.type == 'expense_added' || event.type == 'expense_created') {
        // Don't notify the person who added the expense
        if (event.actorId == currentUserId) return;
        final expenseMap = event.data['expense'] is Map ? event.data['expense'] as Map : event.data;
        final expenseId = expenseMap['id'] as String? ?? event.data['expenseId'] as String?;
        final title = expenseMap['title'] as String? ?? event.data['title'] as String? ?? 'Expense';
        final paidByName = event.data['actorName'] as String? ?? event.data['paidByName'] as String? ?? 'A friend';
        final amountPaise = (expenseMap['amountInPaise'] as int?) ?? (event.data['amountInPaise'] as int?) ?? 0;
        final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
        notifService.addNotification(
          title: 'New Expense Added',
          description: '$paidByName added $formatted ($title).',
          type: NotificationType.expense,
          route: '/trip/${event.tripId}${expenseId != null ? '?expenseId=$expenseId' : ''}',
          actionLabel: 'View Expense',
          idempotencyKey: expenseId != null ? '${expenseId}_created' : null,
        );
      } else if (event.type == 'expense_updated') {
        if (event.actorId == currentUserId) return;
        final expenseMap = event.data['expense'] is Map ? event.data['expense'] as Map : event.data;
        final expenseId = expenseMap['id'] as String? ?? event.data['expenseId'] as String?;
        final title = expenseMap['title'] as String? ?? event.data['title'] as String? ?? 'Expense';
        final actorName = event.data['actorName'] as String? ?? 'A friend';
        final amountPaise = (expenseMap['amountInPaise'] as int?) ?? (event.data['amountInPaise'] as int?) ?? 0;
        final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
        notifService.addNotification(
          title: 'Expense Updated',
          description: '$actorName updated "$title" ($formatted).',
          type: NotificationType.expense,
          route: '/trip/${event.tripId}${expenseId != null ? '?expenseId=$expenseId' : ''}',
          actionLabel: 'View Expense',
          idempotencyKey: expenseId != null ? '${expenseId}_updated_${DateTime.now().minute}' : null,
        );
      } else if (event.type == 'expense_deleted') {
        if (event.actorId == currentUserId) return;
        final actorName = event.data['actorName'] as String? ?? 'A friend';
        final expenseId = event.data['expenseId'] as String?;
        notifService.addNotification(
          title: 'Expense Removed',
          description: '$actorName removed an expense from the trip.',
          type: NotificationType.expense,
          route: '/trip/${event.tripId}',
          actionLabel: 'View Trip',
          idempotencyKey: expenseId != null ? '${expenseId}_deleted' : null,
        );
      } else if (event.type == 'member_joined') {
        if (event.actorId == currentUserId) return;
        final memberName = event.data['memberName'] as String? ?? 'A friend';
        notifService.addNotification(
          title: 'New Member Joined ✈️',
          description: '$memberName joined the trip crew!',
          type: NotificationType.trip,
          route: '/trip/${event.tripId}',
          actionLabel: 'View Trip',
        );
      }
    });
  }

  Future<void> _refreshAllData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        final homeVm = context.read<HomeViewModel>();
        final personalVm = context.read<PersonalExpenseViewModel>();
        final apiClient = context.read<ApiClient>();
        final syncService = context.read<SyncService>();
        final storage = context.read<LocalStorageService>();
        final notifService = context.read<NotificationService>();
        final fcmService = context.read<FcmService>();

        await syncService.flushQueue(apiClient);
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);

        // Ensure Android 13+ notification permissions and FCM push registration
        try {
          final permGranted = await PermissionService.requestNotificationPermission();
          if (permGranted) {
            await fcmService.registerToken();
          }
        } catch (_) {}

        // Check if user has not configured payment receiving method
        if (!storage.hasPaymentMethodConfigured()) {
          final existing = notifService.getNotifications();
          final alreadyNotified = existing.any((n) => n.route == '/payment-methods');
          if (!alreadyNotified) {
            await notifService.addNotification(
              title: 'Set Up Receiving UPI & QR ⚡',
              description: 'Add your UPI ID so trip friends can settle balances directly to your account with 1 tap.',
              type: NotificationType.system,
              route: '/payment-methods',
              actionLabel: 'Set Up Now',
            );
          }
        }

        if (mounted) {
          final widgetService = context.read<KithWidgetService>();
          final versionVm = Provider.of<VersionViewModel?>(context, listen: false);
          final expenseRepo = context.read<ExpenseRepository>();
          final notifService = context.read<NotificationService>();
          final apiClient = context.read<ApiClient>();

          await widgetService.syncSnapshot(
            currentUser: user,
            personalExpenses: personalVm.expenses,
            budget: personalVm.budget,
            debtsSummary: personalVm.debtsSummary,
            trips: homeVm.trips,
            tripBalances: homeVm.tripBalances,
          );
          if (versionVm != null) {
            await versionVm.checkForUpdates();
          }
          await expenseRepo.syncPendingVerifications(user.id);
          await notifService.syncServerNotifications(apiClient);

          if (mounted) {
            await PaymentVerificationManager.checkAndPrompt(context, syncServer: false);
            if (mounted) {
              await KithUpdatePopupDialog.showIfAvailable(context);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeView] Data refresh notice: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final versionVm = Provider.of<VersionViewModel?>(context);
    final user = authVm.currentUser;
    final l10n = context.l10n;

    if (versionVm?.shouldBlockApp == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.go('/update-required');
      });
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        body: const SizedBox.shrink(),
      );
    }

    if (!authVm.isAuthenticated || user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.go('/onboarding');
      });
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        body: const SizedBox.shrink(),
      );
    }

    final mode = authVm.appExperienceMode;
    final List<Widget> pages;
    final List<NavigationDestination> destinations;

    switch (mode) {
      case AppExperienceMode.tripsOnly:
        pages = const [
          DashboardTab(),
          TripsHomeTab(),
          ProfileHomeTab(),
        ];
        destinations = [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, size: 22),
            selectedIcon: const Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flight_takeoff_outlined, size: 22),
            selectedIcon: const Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navTrips,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            selectedIcon: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navProfile,
          ),
        ];
        break;

      case AppExperienceMode.tripsAndExpenses:
        pages = const [
          DashboardTab(),
          TripsHomeTab(),
          PersonalHomeTab(),
          ProfileHomeTab(),
        ];
        destinations = [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, size: 22),
            selectedIcon: const Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flight_takeoff_outlined, size: 22),
            selectedIcon: const Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navTrips,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined, size: 22),
            selectedIcon: const Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navPersonal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            selectedIcon: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navProfile,
          ),
        ];
        break;

      case AppExperienceMode.tripsAndIpo:
        pages = const [
          DashboardTab(),
          TripsHomeTab(),
          IpoHomeView(isEmbeddedTab: true),
          ProfileHomeTab(),
        ];
        destinations = [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, size: 22),
            selectedIcon: const Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flight_takeoff_outlined, size: 22),
            selectedIcon: const Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navTrips,
          ),
          const NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined, size: 22),
            selectedIcon: Icon(Icons.candlestick_chart_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: 'IPO',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            selectedIcon: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navProfile,
          ),
        ];
        break;

      case AppExperienceMode.all:
        pages = const [
          DashboardTab(),
          TripsHomeTab(),
          PersonalHomeTab(),
          IpoHomeView(isEmbeddedTab: true),
          ProfileHomeTab(),
        ];
        destinations = [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, size: 22),
            selectedIcon: const Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flight_takeoff_outlined, size: 22),
            selectedIcon: const Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navTrips,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined, size: 22),
            selectedIcon: const Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navPersonal,
          ),
          const NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined, size: 22),
            selectedIcon: Icon(Icons.candlestick_chart_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: 'IPO',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            selectedIcon: const Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
            label: l10n.navProfile,
          ),
        ];
        break;
    }

    final activeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: activeIndex,
              children: pages,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: UpdateAvailableBanner(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.25 : 0.16),
          height: 64,
          onDestinationSelected: (index) {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
              HapticHelper.selection();
            }
          },
          destinations: destinations,
        ),
      ),
    );
  }
}
