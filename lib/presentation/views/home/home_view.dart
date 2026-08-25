import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../widgets/progress/progress.dart';
import '../personal/personal_home_tab.dart';
import '../personal/widgets/add_personal_expense_sheet.dart';
import '../trip/trips_home_tab.dart';
import 'widgets/profile_sheet.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0; // 0 = Expense (Personal), 1 = Trips (Group)
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
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

        await syncService.flushQueue(apiClient);
        await homeVm.loadTrips(user.id);
        await personalVm.loadData(user.id);
        await personalVm.syncTripExpenses(user.id);
      }
    } catch (e) {
      debugPrint('[HomeView] Data refresh notice: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showProfileSheet() {
    ProfileSheet.show(
      context,
      onSwitchToTrips: () {
        if (mounted) setState(() => _currentIndex = 1);
      },
      onShowRestoreAccount: (ctx) => _showRestoreAccountDialog(),
    );
  }

  void _showRestoreAccountDialog() {
    final keyController = TextEditingController();
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore from Recovery Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the recovery key of the account you want to restore or switch to.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g. KITH-XXXX-YYYY or XXXX-YYYY',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final key = keyController.text.trim();
                if (key.isEmpty) return;
                Navigator.pop(ctx);

                final stageNotifier = ValueNotifier<int>(0);
                final stages = const [
                  ProgressStage(label: 'Validating recovery key', description: 'Checking hash on server'),
                  ProgressStage(label: 'Restoring account session', description: 'Loading canonical user identity'),
                  ProgressStage(label: 'Syncing cloud data', description: 'Restoring trips, expenses & balances'),
                ];

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dCtx) => ValueListenableBuilder<int>(
                    valueListenable: stageNotifier,
                    builder: (c, activeStage, _) {
                      final isDark = Theme.of(c).brightness == Brightness.dark;
                      return Dialog(
                        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: KithStageProgress(
                            title: 'Restoring account…',
                            stages: stages,
                            currentStageIndex: activeStage,
                          ),
                        ),
                      );
                    },
                  ),
                );

                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted) stageNotifier.value = 1;
                });
                Future.delayed(const Duration(milliseconds: 550), () {
                  if (mounted) stageNotifier.value = 2;
                });

                final restoredUser = await authVm.recoverSession(key);

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

                  if (restoredUser != null) {
                    final syncService = context.read<SyncService>();
                    final apiClient = context.read<ApiClient>();
                    await syncService.flushQueue(apiClient);
                    await homeVm.loadTrips(restoredUser.id);
                    await personalVm.loadData(restoredUser.id);
                    await personalVm.syncTripExpenses(restoredUser.id);

                    if (mounted) {
                      KithSuccessToast.show(context, 'Account restored for ${restoredUser.displayName} ✓');
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not restore session. Please verify your recovery code.')),
                    );
                  }
                }
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authVm = context.watch<AuthViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final user = authVm.currentUser;
    final isTripsOnly = authVm.appExperienceMode == AppExperienceMode.tripsOnly;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            GestureDetector(
              onTap: _showProfileSheet,
              child: MemberAvatar(
                name: user?.displayName ?? 'Traveler',
                size: 34,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  user?.displayName ?? 'Traveler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
            onPressed: () {
              HapticHelper.light();
              themeVm.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            onPressed: () => context.push('/join-trip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isTripsOnly
          ? const TripsHomeTab()
          : IndexedStack(
              index: _currentIndex,
              children: const [
                PersonalHomeTab(),
                TripsHomeTab(),
              ],
            ),
      bottomNavigationBar: isTripsOnly
          ? null
          : Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: AppColors.emeraldPrimary.withValues(alpha: 0.16),
                height: 64,
                onDestinationSelected: (index) {
                  if (_currentIndex != index) {
                    setState(() => _currentIndex = index);
                    HapticHelper.selection();
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined, size: 22),
                    selectedIcon: Icon(Icons.receipt_long_rounded, size: 22, color: AppColors.emeraldPrimary),
                    label: 'Expenses',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.flight_takeoff_outlined, size: 22),
                    selectedIcon: Icon(Icons.flight_takeoff_rounded, size: 22, color: AppColors.emeraldPrimary),
                    label: 'Trips',
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticHelper.light();
          if (!isTripsOnly && _currentIndex == 0) {
            AddPersonalExpenseSheet.show(context);
          } else {
            context.push('/create-trip');
          }
        },
        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          (!isTripsOnly && _currentIndex == 0) ? 'Add Expense' : 'New Trip',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
