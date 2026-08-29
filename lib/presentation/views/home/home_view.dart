import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/kith_widget_service.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../../domain/services/notification_service.dart';
import '../../router/app_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../personal/personal_home_tab.dart';
import '../profile/profile_home_tab.dart';
import '../trip/trips_home_tab.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
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
    final user = authVm.currentUser;

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
        ? const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.flight_takeoff_outlined, size: 22),
              selectedIcon: Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Trips',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 22),
              selectedIcon: Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Profile',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.flight_takeoff_outlined, size: 22),
              selectedIcon: Icon(Icons.flight_takeoff_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Trips',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 22),
              selectedIcon: Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Expenses',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 22),
              selectedIcon: Icon(Icons.person_rounded, size: 22, color: Color(0xFF14B8A6)),
              label: 'Profile',
            ),
          ];

    final activeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: IndexedStack(
          index: activeIndex,
          children: pages,
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
