import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/realtime_client.dart';
import '../../../core/services/kith_widget_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../../domain/services/notification_service.dart';
import '../../router/app_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../viewmodels/version_viewmodel.dart';
import '../personal/personal_home_tab.dart';
import '../profile/profile_home_tab.dart';
import '../trip/trips_home_tab.dart';
import '../version/update_available_banner.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
      _setupRealtimeListener();
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

      if (event.type == 'settlement_marked_paid') {
        // Y receives notification that X marked payment as paid
        final nd = notifData(event);
        if (isRecipient(nd)) {
          final fromName = nd['payerName'] as String? ?? nd['fromName'] as String? ?? 'A member';
          final amountPaise = nd['amountInPaise'] as int? ?? 0;
          final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
          notifService.addNotification(
            title: 'Payment Sent — Confirm Receipt 💸',
            description: '$fromName marked $formatted as paid to you. Tap to confirm.',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}',
            actionLabel: 'Confirm',
            idempotencyKey: '${event.data['settlementId'] ?? event.eventId}_marked_paid',
          );
        }
      } else if (event.type == 'settlement_recorded') {
        // Legacy event type — handle same as settlement_marked_paid for backward compat
        final nd = notifData(event);
        if (isRecipient(nd)) {
          final fromName = nd['payerName'] as String? ?? nd['fromName'] as String? ?? 'A member';
          final amountPaise = nd['amountInPaise'] as int? ?? 0;
          final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
          notifService.addNotification(
            title: 'Payment Received — Confirm 💸',
            description: '$fromName marked $formatted as paid to you.',
            type: NotificationType.settlement,
            route: '/trip/${event.tripId}',
            actionLabel: 'Confirm',
            idempotencyKey: '${event.data['settlementId'] ?? event.eventId}_recorded',
          );
        }
      } else if (event.type == 'settlement_confirmed') {
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
        final title = event.data['title'] as String? ?? 'Expense';
        final paidByName = event.data['paidByName'] as String? ?? 'A friend';
        final amountPaise = event.data['amountInPaise'] as int? ?? 0;
        final formatted = CurrencyFormatter.formatPaise(amountPaise, currencyCode: 'INR');
        notifService.addNotification(
          title: 'New Expense Added 🧾',
          description: '$paidByName added "$title" ($formatted).',
          type: NotificationType.expense,
          route: '/trip/${event.tripId}',
          actionLabel: 'View Expense',
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

        await syncService.flushQueue(apiClient);
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);

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
          await widgetService.syncSnapshot(
            currentUser: user,
            personalExpenses: personalVm.expenses,
            budget: personalVm.budget,
            debtsSummary: personalVm.debtsSummary,
            trips: homeVm.trips,
            tripBalances: homeVm.tripBalances,
          );
          if (!mounted) return;
          final versionVm = Provider.of<VersionViewModel?>(context, listen: false);
          if (versionVm != null) {
            await versionVm.checkForUpdates();
          }
          if (mounted) {
            await PaymentVerificationManager.checkAndPrompt(context);
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

    final isTripsOnly = authVm.appExperienceMode == AppExperienceMode.tripsOnly;
    final pages = isTripsOnly
        ? const [
            DashboardTab(),
            TripsHomeTab(),
            ProfileHomeTab(),
          ]
        : const [
            DashboardTab(),
            TripsHomeTab(),
            PersonalHomeTab(),
            ProfileHomeTab(),
          ];

    final destinations = isTripsOnly
        ? [
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
          ]
        : [
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
