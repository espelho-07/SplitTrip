import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../data/services/local_storage_service.dart';
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
              const SizedBox(height: AppSpacing.xl),
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
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'Server & Cloud Sync',
                icon: Icons.cloud_sync_outlined,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showServerConfigDialog();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Restore / Switch Account',
                icon: Icons.sync_rounded,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRestoreAccountDialog();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                text: 'Send Beta Feedback',
                icon: Icons.feedback_outlined,
                isFullWidth: true,
                variant: AppButtonVariant.secondary,
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
                    await homeVm.loadTrips(restoredUser.id);
                    await personalVm.loadData(restoredUser.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🎉 Restored account for "${restoredUser.displayName}"!')),
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          PersonalHomeTab(),
          TripsHomeTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
            HapticHelper.selection();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Expense',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff_rounded),
            label: 'Trips',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticHelper.light();
          if (_currentIndex == 0) {
            AddPersonalExpenseSheet.show(context);
          } else {
            context.push('/create-trip');
          }
        },
        backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          _currentIndex == 0 ? 'Add Expense' : 'New Trip',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
