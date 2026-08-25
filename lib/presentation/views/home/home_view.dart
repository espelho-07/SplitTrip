import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/services/local_storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user != null) {
      context.read<HomeViewModel>().loadTrips(user.id);
      context.read<PersonalExpenseViewModel>().loadData(user.id);
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
      onShowLinkAccount: (ctx) => _showLinkAccountDialog(),
      onShowRestoreAccount: (ctx) => _showRestoreAccountDialog(),
      onShowServerConfig: (ctx) => _showServerConfigDialog(),
    );
  }

  void _showLinkAccountDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController(text: context.read<AuthViewModel>().currentUser?.displayName ?? '');
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final syncService = context.read<SyncService>();
    final apiClient = context.read<ApiClient>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.g_mobiledata_rounded, color: AppColors.emeraldPrimary, size: 28),
              SizedBox(width: 6),
              Text('Continue with Google', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sync your Kith account across devices. All your existing trips, expenses, and balances will stay permanently linked.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Google Email Address',
                    hintText: 'you@gmail.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final name = nameController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid Google email address.')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final stageNotifier = ValueNotifier<int>(0);
                final stages = const [
                  ProgressStage(label: 'Connecting Google account', description: 'Linking Google credential'),
                  ProgressStage(label: 'Verifying canonical ledger', description: 'Migrating guest records securely'),
                  ProgressStage(label: 'Syncing trips & balances', description: 'Backing up all data to cloud'),
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
                            title: 'Syncing your account…',
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

                final updated = await authVm.signInWithGoogle(
                  email: email,
                  displayName: name.isEmpty ? email.split('@')[0] : name,
                  googleId: 'g_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
                );

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress

                  if (updated != null) {
                    await syncService.flushQueue(apiClient);
                    await homeVm.loadTrips(updated.id);
                    await personalVm.loadData(updated.id);
                    await personalVm.syncTripExpenses(updated.id);

                    if (mounted) {
                      KithSuccessToast.show(context, 'Account linked to ${updated.email} ✓');
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authVm.errorMessage ?? 'Could not sign in with Google.')),
                      );
                    }
                  }
                }
              },
              child: const Text('Continue with Google'),
            ),
          ],
        );
      },
    );
  }

  void _showServerConfigDialog() {
    final storage = context.read<LocalStorageService>();
    final currentCustomUrl = storage.getSavedServerUrl() ?? '';
    final urlController = TextEditingController(text: currentCustomUrl);
    String statusMessage = '';
    bool isTesting = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: AppColors.emeraldPrimary, size: 22),
                  SizedBox(width: 8),
                  Text('Server & Cloud Sync', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure your Render or backend server URL. Leave empty to use default staging cloud.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'https://your-service.onrender.com',
                        prefixIcon: Icon(Icons.link_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Active URL: ${AppConfig.baseUrl}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                    ),
                    if (statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSuccess ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSuccess ? Colors.green : Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: isSuccess ? Colors.green : Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage,
                                style: TextStyle(fontSize: 12, color: isSuccess ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isTesting ? null : () async {
                    setDialogState(() {
                      isTesting = true;
                      statusMessage = 'Testing connection...';
                    });

                    final testUrl = urlController.text.trim();
                    final targetBase = testUrl.isNotEmpty
                        ? (testUrl.endsWith('/') ? testUrl.substring(0, testUrl.length - 1) : testUrl)
                        : 'https://kith-staging-backend.onrender.com';
                    final healthUrl = Uri.parse('$targetBase/health');

                    try {
                      final client = http.Client();
                      final res = await client.get(healthUrl).timeout(const Duration(seconds: 6));
                      if (res.statusCode == 200) {
                        setDialogState(() {
                          isTesting = false;
                          isSuccess = true;
                          statusMessage = 'Connected! Server is healthy (200 OK)';
                        });
                      } else {
                        setDialogState(() {
                          isTesting = false;
                          isSuccess = false;
                          statusMessage = 'Server responded with status HTTP ${res.statusCode}';
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        isTesting = false;
                        isSuccess = false;
                        statusMessage = 'Could not reach server: $e';
                      });
                    }
                  },
                  child: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test Connection'),
                ),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogCtx);
                    final entered = urlController.text.trim();
                    await storage.saveServerUrl(entered.isEmpty ? null : entered);
                    AppConfig.setCustomServerUrl(entered.isEmpty ? null : entered);
                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Server URL updated to: ${AppConfig.baseUrl}')),
                      );
                    }
                  },
                  child: const Text('Save & Apply'),
                ),
              ],
            );
          },
        );
      },
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
