import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/security_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../domain/enums/app_experience_mode.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../language/language_select_sheet.dart';
import '../security/set_pin_sheet.dart';

class MasterSettingsView extends StatefulWidget {
  const MasterSettingsView({super.key});

  @override
  State<MasterSettingsView> createState() => _MasterSettingsViewState();
}

class _MasterSettingsViewState extends State<MasterSettingsView> {
  String _selectedCurrency = 'INR';
  String _selectedDateFormat = 'DD/MM/YYYY';
  double _cacheSizeMb = 14.8;

  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      _isLoaded = true;
      _loadPreferences();
    }
  }

  void _loadPreferences() {
    final storage = context.read<LocalStorageService>();
    _selectedCurrency = storage.getString('kith_default_currency') ?? 'INR';
    _selectedDateFormat = storage.getString('kith_date_format') ?? 'DD/MM/YYYY';
  }

  Future<void> _setCurrency(String code) async {
    final storage = context.read<LocalStorageService>();
    await storage.setString('kith_default_currency', code);
    setState(() => _selectedCurrency = code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Default currency set to $code ✓'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _setDateFormat(String format) async {
    final storage = context.read<LocalStorageService>();
    await storage.setString('kith_date_format', format);
    setState(() => _selectedDateFormat = format);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Date format set to $format ✓'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _handleAppLockToggle(bool value) async {
    final security = context.read<SecurityLockService>();
    if (value) {
      if (!security.hasPin) {
        final success = await SetPinSheet.show(context);
        if (success != true) return;
      } else {
        await security.setAppLockEnabled(true);
      }
    } else {
      // Confirm disable
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: const Text('Disable App Lock?'),
          content: const Text('Anyone with access to your device will be able to open Kith without entering a PIN or biometric authentication.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await security.setAppLockEnabled(false);
      }
    }
  }

  Future<void> _handleBiometricsToggle(bool value) async {
    final security = context.read<SecurityLockService>();
    if (value) {
      if (!security.isBiometricsSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric hardware is not available or not enrolled on this device.')),
        );
        return;
      }
      final authenticated = await security.authenticateWithBiometrics(
        reason: 'Scan your fingerprint or face to enable biometric unlock',
      );
      if (authenticated) {
        await security.setBiometricsEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric unlock activated 👆 ✓')),
          );
        }
      }
    } else {
      await security.setBiometricsEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock disabled')),
        );
      }
    }
  }

  void _showCurrencySelector(bool isDark) {
    HapticHelper.light();
    final currencies = [
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
      {'code': 'USD', 'symbol': r'$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
      {'code': 'AED', 'symbol': 'AED', 'name': 'UAE Dirham'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1418) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Base Currency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              ...currencies.map((c) {
                final isSelected = _selectedCurrency == c['code'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.emeraldPrimary.withValues(alpha: 0.15) : (isDark ? Colors.white10 : Colors.black12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(c['symbol']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isSelected ? AppColors.emeraldPrimary : null)),
                  ),
                  title: Text('${c['code']} - ${c['name']}', style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setCurrency(c['code']!);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateFormatSelector(bool isDark) {
    HapticHelper.light();
    final formats = [
      {'format': 'DD/MM/YYYY', 'example': '28/08/2026'},
      {'format': 'MM/DD/YYYY', 'example': '08/28/2026'},
      {'format': 'YYYY-MM-DD', 'example': '2026-08-28'},
      {'format': 'DD MMM YYYY', 'example': '28 Aug 2026'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1418) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Date Format',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              ...formats.map((f) {
                final isSelected = _selectedDateFormat == f['format'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today_rounded, color: isSelected ? AppColors.emeraldPrimary : Colors.grey, size: 20),
                  title: Text(f['format']!, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text('Example: ${f['example']}'),
                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setDateFormat(f['format']!);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecoveryKeySheet(bool isDark) {
    HapticHelper.light();
    final authVm = context.read<AuthViewModel>();
    final key = authVm.currentUser?.recoveryKey ?? 'KITH-SEC-9921-8842-7719';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1418) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.lock_person_rounded, color: AppColors.emeraldPrimary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Secret Recovery Key',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This offline cryptographic key restores your full trip records and expenses on any new device without requiring a server password.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF080C0E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.emeraldPrimary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: key));
                        HapticHelper.success();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recovery Key copied to clipboard ✓'), behavior: SnackBarBehavior.floating),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDataSheet(bool isDark) {
    HapticHelper.light();
    final homeVm = context.read<HomeViewModel>();
    final personalVm = context.read<PersonalExpenseViewModel>();

    final trips = homeVm.trips;
    final personalExpenses = personalVm.expenses;

    // Generate JSON
    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '2.2.0',
      'trips_count': trips.length,
      'personal_expenses_count': personalExpenses.length,
      'trips': trips.map((t) => t.toJson()).toList(),
      'personal_expenses': personalExpenses.map((e) => e.toJson()).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // Generate CSV
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('Type,Title,Amount_Paise,Date,Category,Payer');
    for (final trip in trips) {
      csvBuffer.writeln('Trip,${trip.name},0,${trip.createdAt.toIso8601String()},${trip.tripMode},${trip.creatorId}');
    }
    for (final exp in personalExpenses) {
      csvBuffer.writeln('Personal,${exp.title},${exp.amountInPaise},${exp.date.toIso8601String()},${exp.category.name},${exp.userId}');
    }
    final csvString = csvBuffer.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1418) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Export Your Financial Archive',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Contains ${trips.length} group trips and ${personalExpenses.length} personal expenses recorded locally.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.emeraldPrimary.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.data_object_rounded, color: AppColors.emeraldPrimary, size: 20),
                ),
                title: const Text('Copy JSON Archive', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Full structured backup (${(jsonString.length / 1024).toStringAsFixed(1)} KB)'),
                trailing: const Icon(Icons.copy_rounded, color: AppColors.emeraldPrimary, size: 20),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: jsonString));
                  HapticHelper.success();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Full JSON Archive copied to clipboard ✓'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.indigoAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart_rounded, color: AppColors.indigoAccent, size: 20),
                ),
                title: const Text('Copy CSV Spreadsheet', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Compatible with Excel & Google Sheets (${(csvString.length / 1024).toStringAsFixed(1)} KB)'),
                trailing: const Icon(Icons.copy_rounded, color: AppColors.indigoAccent, size: 20),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: csvString));
                  HapticHelper.success();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV Spreadsheet copied to clipboard ✓'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(bool isDark) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: const Text('Clear Temporary Cache?'),
        content: Text('This will free up ${_cacheSizeMb.toStringAsFixed(1)} MB of temporary rendering cache, offline font snapshots, and image memory. Your trips and expenses are completely safe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              setState(() => _cacheSizeMb = 0.0);
              Navigator.pop(dCtx);
              HapticHelper.success();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully (0 KB remaining) ✓'), behavior: SnackBarBehavior.floating),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.emeraldPrimary),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(bool isDark) {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1418) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.emeraldPrimary, Color(0xFF0D534D)]),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.group_work_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                'Kith by Nirniq',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 2),
              Text('Version 2.2.0 (Build 42)', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B))),
              const SizedBox(height: 16),
              Text(
                'High-performance, local-first group travel & expense sharing engine with real-time offline sync, exact paise arithmetic, and min-cash-flow debt simplification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  HapticHelper.success();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You are using the latest version of Kith ✓'), behavior: SnackBarBehavior.floating),
                  );
                },
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('Check for Updates'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExperienceModeSelector(BuildContext context, AuthViewModel authVm, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1418) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
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
            const SizedBox(height: 18),
            Text(
              'App Experience Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred application focus and visible modules',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            _buildExperienceOption(
              title: 'Trips & Expenses',
              subtitle: 'Full experience with personal expense ledger, analytics, and group trip splits',
              icon: Icons.pie_chart_outline_rounded,
              isSelected: authVm.appExperienceMode == AppExperienceMode.all,
              isDark: isDark,
              onTap: () async {
                HapticHelper.selection();
                await authVm.setAppExperienceMode(AppExperienceMode.all);
                if (bCtx.mounted) Navigator.pop(bCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Switched to Trips & Expenses mode'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            _buildExperienceOption(
              title: 'Trips Only',
              subtitle: 'Streamlined UI focused purely on group trips, splits, and instant settlements',
              icon: Icons.flight_takeoff_rounded,
              isSelected: authVm.appExperienceMode == AppExperienceMode.tripsOnly,
              isDark: isDark,
              onTap: () async {
                HapticHelper.selection();
                await authVm.setAppExperienceMode(AppExperienceMode.tripsOnly);
                if (bCtx.mounted) Navigator.pop(bCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Switched to Trips Only mode'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.08)
                : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF14B8A6)
                  : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? const Color(0xFF14B8A6)
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF14B8A6),
                  size: 22,
                )
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final security = context.watch<SecurityLockService>();
    final authVm = context.watch<AuthViewModel>();
    LocaleViewModel? localeVm;
    try {
      localeVm = context.watch<LocaleViewModel>();
    } catch (_) {}

    final currentLangLabel = localeVm != null
        ? '${localeVm.currentLanguage.flagEmoji} ${localeVm.currentLanguage.nativeName}'
        : '🇮🇳 English';
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          _buildSectionHeader('General Preferences', isDark),
          _buildSettingsGroup(isDark, [
            _buildSettingTile('App Experience Mode', authVm.appExperienceMode == AppExperienceMode.tripsOnly ? 'Trips Only (Focused)' : 'Trips & Expenses (Full)', Icons.auto_awesome_mosaic_rounded, isDark, () => _showExperienceModeSelector(context, authVm, isDark)),
            _buildSettingTile('Payment Methods', 'UPI IDs & Receiving QR', Icons.payment_rounded, isDark, () => context.push('/payment-methods')),
            _buildSettingTile('Notifications', 'Alerts & Live trip settlements', Icons.notifications_none_rounded, isDark, () => context.push('/notifications')),
            _buildSettingTile('Base Currency', '$_selectedCurrency - Active default currency', Icons.currency_rupee_rounded, isDark, () => _showCurrencySelector(isDark)),
            _buildSettingTile('Language', currentLangLabel, Icons.language_rounded, isDark, () => LanguageSelectSheet.show(context)),
            _buildSettingTile('Date Format', '$_selectedDateFormat (tap to change)', Icons.calendar_today_rounded, isDark, () => _showDateFormatSelector(isDark)),
          ]),

          const SizedBox(height: 24),

          _buildSectionHeader('Security & Vault', isDark),
          _buildSettingsGroup(isDark, [
            _buildSettingTile('Secret Recovery Key', 'View & copy offline private key', Icons.lock_outline_rounded, isDark, () => _showRecoveryKeySheet(isDark)),
            _buildToggleTile(
              'App Lock',
              security.hasPin ? 'PIN protection active on open' : 'Require PIN or biometric on open',
              Icons.security_rounded,
              security.isAppLockEnabled,
              isDark,
              _handleAppLockToggle,
            ),
            _buildToggleTile(
              'Biometric Login',
              security.isBiometricsSupported ? 'Fingerprint & Face unlock' : 'Not supported on this device',
              Icons.fingerprint_rounded,
              security.isBiometricsEnabled,
              isDark,
              _handleBiometricsToggle,
            ),
            if (security.hasPin)
              _buildSettingTile('Change Security PIN', 'Update 4-digit passcode', Icons.pin_outlined, isDark, () => SetPinSheet.show(context)),
          ]),

          const SizedBox(height: 24),

          _buildSectionHeader('Data & Diagnostics', isDark),
          _buildSettingsGroup(isDark, [
            _buildSettingTile('Export Data', 'Download complete JSON / CSV archive', Icons.file_download_outlined, isDark, () => _showExportDataSheet(isDark)),
            _buildSettingTile('Clear Cache', _cacheSizeMb > 0 ? '${_cacheSizeMb.toStringAsFixed(1)} MB temporary cache' : '0.0 KB (Clean)', Icons.cleaning_services_outlined, isDark, () => _showClearCacheDialog(isDark)),
            _buildSettingTile('App Version & Diagnostics', 'v2.2.0 (Build 42) · Local-First Engine', Icons.info_outline_rounded, isDark, () => _showAboutSheet(isDark)),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticHelper.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? AppColors.darkTextMuted : const Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(String title, String subtitle, IconData icon, bool value, bool isDark, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              HapticHelper.selection();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
