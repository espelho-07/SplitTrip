import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../personal/personal_home_tab.dart';
import '../personal/widgets/add_personal_expense_sheet.dart';
import '../settings/widgets/beta_feedback_sheet.dart';
import '../trip/trips_home_tab.dart';

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
    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  MemberAvatar(name: user.displayName, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTypography.titleMedium(isDark: isDark),
                        ),
                        Text(
                          user.isLinkedToAccount
                              ? (user.email ?? 'Linked Account')
                              : 'Anonymous Guest Account',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!user.isLinkedToAccount) ...[
                const SizedBox(height: AppSpacing.md),
                SurfaceCard(
                  backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.emeraldPrimary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Guest Account (Not Linked)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Link your account with Email so all your trips, expenses, and balances sync permanently across all your devices.',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        text: 'Link & Secure Account',
                        icon: Icons.link_rounded,
                        isFullWidth: true,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showLinkAccountDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Recovery Key',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Keep this key safe. Use it to recover your trips and personal expenses if you switch devices or reinstall.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.recoveryKey,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.recoveryKey));
                        HapticHelper.success();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recovery key copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'App Modules & Experience',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose whether to focus exclusively on group trips or use the full suite with personal finance.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Mode 1: Trips Only
              InkWell(
                onTap: () async {
                  HapticHelper.selection();
                  await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
                  if (mounted) {
                    setState(() => _currentIndex = 1);
                  }
                },
                borderRadius: AppRadius.mdBorder,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: authVm.appExperienceMode == AppExperienceMode.tripsOnly
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
                        : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                    borderRadius: AppRadius.mdBorder,
                    border: Border.all(
                      color: authVm.appExperienceMode == AppExperienceMode.tripsOnly
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      width: authVm.appExperienceMode == AppExperienceMode.tripsOnly ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('✈️', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trips & Group Splitting Only',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Clean interface focused purely on trips and balances',
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                      if (authVm.appExperienceMode == AppExperienceMode.tripsOnly)
                        const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Mode 2: Both Trips & Personal Expenses
              InkWell(
                onTap: () async {
                  HapticHelper.selection();
                  await authVm.setAppExperienceMode(AppExperienceMode.all);
                },
                borderRadius: AppRadius.mdBorder,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: authVm.appExperienceMode == AppExperienceMode.all
                        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12)
                        : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                    borderRadius: AppRadius.mdBorder,
                    border: Border.all(
                      color: authVm.appExperienceMode == AppExperienceMode.all
                          ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                          : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      width: authVm.appExperienceMode == AppExperienceMode.all ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💼', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trips & Personal Expenses',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Full suite with personal tracker, lending/borrowing, & budgets',
                              style: AppTypography.bodySmall(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                      if (authVm.appExperienceMode == AppExperienceMode.all)
                        const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'Sync All Data with Cloud',
                icon: Icons.cloud_sync_rounded,
                isFullWidth: true,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('⟳ Syncing all trips & expenses with cloud...')),
                  );
                  final apiClient = context.read<ApiClient>();
                  final syncService = context.read<SyncService>();
                  final homeVm = context.read<HomeViewModel>();
                  final personalVm = context.read<PersonalExpenseViewModel>();

                  await syncService.flushQueue(apiClient);
                  await homeVm.loadTrips(user.id);
                  await personalVm.loadData(user.id);
                  await personalVm.syncTripExpenses(user.id);

                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('🎉 Everything is up to date and in sync with cloud!')),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Restore / Switch Account',
                icon: Icons.vpn_key_rounded,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRestoreAccountDialog();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Server & Cloud Settings',
                icon: Icons.dns_outlined,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showServerConfigDialog();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Send Beta Feedback',
                icon: Icons.feedback_outlined,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const BetaFeedbackSheet(currentScreenContext: 'Home Profile'),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Done',
                isFullWidth: true,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
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
              Icon(Icons.link_rounded, color: AppColors.emeraldPrimary, size: 22),
              SizedBox(width: 8),
              Text('Link & Sync Account', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link your guest session to your email. All your existing trips, expenses, lending records, and budgets will be permanently backed up to the cloud.',
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
                    labelText: 'Email Address',
                    hintText: 'you@example.com',
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
                    const SnackBar(content: Text('Please enter a valid email address.')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Linking account & syncing data with cloud...')),
                );

                final updated = await authVm.linkAccount(email: email, displayName: name.isEmpty ? null : name);
                if (updated != null) {
                  await syncService.flushQueue(apiClient);
                  await homeVm.loadTrips(updated.id);
                  await personalVm.loadData(updated.id);
                  await personalVm.syncTripExpenses(updated.id);

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('🎉 Account linked to ${updated.email}! All trips & finances synced.')),
                    );
                  }
                } else {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(authVm.errorMessage ?? 'Could not link account.')),
                    );
                  }
                }
              },
              child: const Text('Link & Sync All'),
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

                final restoredUser = await authVm.recoverSession(key);
                if (mounted) {
                  if (restoredUser != null) {
                    final syncService = context.read<SyncService>();
                    final apiClient = context.read<ApiClient>();
                    await syncService.flushQueue(apiClient);
                    await homeVm.loadTrips(restoredUser.id);
                    await personalVm.loadData(restoredUser.id);
                    await personalVm.syncTripExpenses(restoredUser.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🎉 Restored account for "${restoredUser.displayName}" & synced all trips!')),
                      );
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
