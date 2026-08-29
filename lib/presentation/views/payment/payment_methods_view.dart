import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/kith_components.dart';
import '../../../data/services/local_storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SavedUpiItem {
  final String id;
  final String vpa;
  final String name;
  final String appName;
  final IconData icon;
  final Color iconColor;
  bool isDefault;

  SavedUpiItem({
    required this.id,
    required this.vpa,
    required this.name,
    required this.appName,
    required this.icon,
    required this.iconColor,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vpa': vpa,
    'name': name,
    'appName': appName,
    'iconCode': icon.codePoint,
    'iconColorValue': iconColor.toARGB32(),
    'isDefault': isDefault,
  };

  factory SavedUpiItem.fromJson(Map<String, dynamic> json) {
    return SavedUpiItem(
      id: json['id'] as String,
      vpa: json['vpa'] as String,
      name: json['name'] as String? ?? 'User',
      appName: json['appName'] as String? ?? 'UPI VPA',
      icon: Icons.payment_rounded,
      iconColor: Color(json['iconColorValue'] as int? ?? AppColors.emeraldPrimary.toARGB32()),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class PaymentMethodsView extends StatefulWidget {
  const PaymentMethodsView({super.key});

  @override
  State<PaymentMethodsView> createState() => _PaymentMethodsViewState();
}

class _PaymentMethodsViewState extends State<PaymentMethodsView> {
  static const String _storageKey = 'kith_saved_upi_items';
  List<SavedUpiItem> _savedUpis = [];
  double _customAmount = 0.0;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final storage = context.read<LocalStorageService>();
        final raw = storage.getString(_storageKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          setState(() {
            _savedUpis = list.map((item) => SavedUpiItem.fromJson(item as Map<String, dynamic>)).toList();
          });
        } else {
          // Check if user has a primary UPI ID from their account
          final primaryUpi = storage.getPrimaryUpiId();
          final user = context.read<LocalStorageService>().getSavedUser();
          final vpa = primaryUpi ?? (user != null ? user['upiId'] as String? : null);
          if (vpa != null && vpa.isNotEmpty) {
            final userName = user != null ? (user['displayName'] as String? ?? 'User') : 'User';
            final item = SavedUpiItem(
              id: 'upi_${DateTime.now().millisecondsSinceEpoch}',
              vpa: vpa,
              name: userName,
              appName: 'UPI VPA',
              icon: Icons.payments_rounded,
              iconColor: AppColors.emeraldPrimary,
              isDefault: true,
            );
            setState(() {
              _savedUpis = [item];
            });
            _persistUpis();
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _persistUpis() async {
    try {
      final storage = context.read<LocalStorageService>();
      final jsonList = _savedUpis.map((u) => u.toJson()).toList();
      await storage.setString(_storageKey, jsonEncode(jsonList));

      if (_savedUpis.isNotEmpty) {
        final primary = _savedUpis.firstWhere((u) => u.isDefault, orElse: () => _savedUpis.first);
        await storage.setPrimaryUpiId(primary.vpa);
        if (mounted) {
          final authVm = context.read<AuthViewModel>();
          final localStore = context.read<LocalStorageService>();
          try {
            await authVm.updatePaymentInfo(primary.vpa);
          } catch (_) {}
          try {
            await localStore.saveUserToRecoveryVault({
              ...?storage.getSavedUser(),
              'upiId': primary.vpa,
            });
          } catch (_) {}
        }
      } else {
        await storage.setPrimaryUpiId(null);
        if (mounted) {
          final authVm = context.read<AuthViewModel>();
          try {
            await authVm.updatePaymentInfo('');
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  SavedUpiItem? get _primaryUpi =>
      _savedUpis.isNotEmpty
          ? _savedUpis.firstWhere((u) => u.isDefault, orElse: () => _savedUpis.first)
          : null;

  String get _dynamicUpiUri {
    final upi = _primaryUpi;
    if (upi == null) return '';
    final buffer = StringBuffer('upi://pay?pa=${upi.vpa}&pn=${Uri.encodeComponent(upi.name)}&cu=INR&tn=${Uri.encodeComponent('Kith Expense Settlement')}');
    if (_customAmount > 0) {
      buffer.write('&am=${_customAmount.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  void _copyToClipboard(String text, String message) {
    HapticHelper.success();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setDefaultUpi(String id) {
    HapticHelper.medium();
    setState(() {
      for (final u in _savedUpis) {
        u.isDefault = u.id == id;
      }
    });
    _persistUpis();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default receiving UPI updated ✓'),
        backgroundColor: AppColors.emeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteUpi(SavedUpiItem item) {
    HapticHelper.light();
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(l10n.paymentDeleteTitle),
        content: Text(l10n.paymentDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(dCtx);
              setState(() {
                _savedUpis.removeWhere((u) => u.id == item.id);
                if (item.isDefault && _savedUpis.isNotEmpty) {
                  _savedUpis.first.isDefault = true;
                }
              });
              _persistUpis();
              HapticHelper.success();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UPI ID deleted ✓')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(l10n.translate('action_delete')),
          ),
        ],
      ),
    );
  }

  void _showAddUpiSheet(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    final vpaController = TextEditingController();
    final nameController = TextEditingController(text: 'Darpan Parmar');
    bool isDefault = _savedUpis.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1418) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
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
                const SizedBox(height: 16),
                Text(
                  l10n.paymentAddBtn,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.paymentReceivingQrSub,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),

                // VPA Input
                TextField(
                  controller: vpaController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'UPI ID (VPA)',
                    hintText: 'e.g. yourname@okhdfcbank or 9876543210@paytm',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF141A20) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Full Name Input
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    hintText: 'e.g. Darpan Parmar',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF141A20) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Set default toggle
                Row(
                  children: [
                    Checkbox(
                      value: isDefault,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (v) {
                        setSheetState(() => isDefault = v ?? false);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Set as primary receiving method',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Save CTA
                FilledButton(
                  onPressed: () {
                    final vpa = vpaController.text.trim().toLowerCase();
                    if (!vpa.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid UPI ID with @')),
                      );
                      return;
                    }
                    HapticHelper.success();
                    
                    // Smart App Icon detection
                    String appName = 'UPI VPA';
                    Color appColor = AppColors.emeraldPrimary;
                    if (vpa.contains('okhdfcbank') || vpa.contains('okaxis') || vpa.contains('oksbi') || vpa.contains('okicici')) {
                      appName = 'Google Pay';
                      appColor = const Color(0xFF4285F4);
                    } else if (vpa.contains('ybl') || vpa.contains('ibl') || vpa.contains('axl')) {
                      appName = 'PhonePe';
                      appColor = const Color(0xFF5F259F);
                    } else if (vpa.contains('paytm')) {
                      appName = 'Paytm UPI';
                      appColor = const Color(0xFF00B9F1);
                    } else if (vpa.contains('cred')) {
                      appName = 'CRED UPI';
                      appColor = const Color(0xFF1E293B);
                    }

                    final newItem = SavedUpiItem(
                      id: 'upi_${DateTime.now().millisecondsSinceEpoch}',
                      vpa: vpa,
                      name: nameController.text.trim().isEmpty ? 'User' : nameController.text.trim(),
                      appName: appName,
                      icon: Icons.payments_rounded,
                      iconColor: appColor,
                      isDefault: isDefault,
                    );

                    setState(() {
                      if (isDefault) {
                        for (final u in _savedUpis) {
                          u.isDefault = false;
                        }
                      }
                      _savedUpis.insert(0, newItem);
                    });
                    _persistUpis();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New UPI ID added successfully ✓')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save UPI Method', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(l10n.paymentMethodsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.emeraldPrimary),
            tooltip: l10n.paymentAddBtn,
            onPressed: () => _showAddUpiSheet(context, isDark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          if (_savedUpis.isEmpty) ...[
            // Empty State Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1418) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.3) : AppColors.emeraldPrimary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.08 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 32,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Payment Method Added',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your receiving UPI ID so friends in trips can settle balances directly to your account with 1 tap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _showAddUpiSheet(context, isDark),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Add Receiving UPI ID',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A20) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.emeraldPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your UPI ID is only visible to members of trips you join, enabling seamless zero-leakage settlements.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Dynamic Live QR Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF10171D), const Color(0xFF0C1216)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.25) : AppColors.emeraldPrimary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.1 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, color: AppColors.emeraldPrimary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.paymentReceivingQr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(_primaryUpi!.appName, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('LIVE UPI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                      ],
                    ),
                    child: QrImageView(
                      data: _dynamicUpiUri,
                      version: QrVersions.auto,
                      size: 180.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // VPA Label
                  Text(
                    _primaryUpi!.vpa,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _primaryUpi!.name,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  // Custom Amount Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF080C0E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Text('₹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            decoration: KithInputDecoration.borderless(
                              hintText: 'Add request amount (Optional)',
                            ),
                            onChanged: (val) {
                              setState(() {
                                _customAmount = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ),
                        if (_customAmount > 0)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _amountController.clear();
                              setState(() => _customAmount = 0.0);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preset Chips
                  Wrap(
                    spacing: 8,
                    children: [100, 250, 500, 1000, 2000].map((amt) {
                      final isSelected = _customAmount == amt.toDouble();
                      return ActionChip(
                        label: Text('₹$amt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : null)),
                        backgroundColor: isSelected ? AppColors.emeraldPrimary : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        onPressed: () {
                          HapticHelper.selection();
                          setState(() {
                            _customAmount = amt.toDouble();
                            _amountController.text = amt.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(_primaryUpi!.vpa, '${l10n.paymentCopyId} ✓'),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(l10n.paymentCopyId),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _copyToClipboard(_dynamicUpiUri, '${l10n.paymentShareLink} ✓'),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: Text(l10n.paymentShareLink),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emeraldPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Saved UPIs List Section
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text(
                l10n.paymentSavedMethods,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                ),
              ),
            ),

            Material(
              color: isDark ? const Color(0xFF0F1418) : Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: _savedUpis.map((upi) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: upi.iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(upi.icon, color: upi.iconColor, size: 20),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            upi.vpa,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (upi.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(l10n.paymentPrimaryBadge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.emeraldPrimary)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(upi.appName, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!upi.isDefault)
                          IconButton(
                            icon: const Icon(Icons.star_outline_rounded, size: 20),
                            tooltip: l10n.paymentSetPrimary,
                            onPressed: () => _setDefaultUpi(upi.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                          tooltip: l10n.paymentDeleteTitle,
                          onPressed: () => _deleteUpi(upi),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!upi.isDefault) {
                        _setDefaultUpi(upi.id);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
