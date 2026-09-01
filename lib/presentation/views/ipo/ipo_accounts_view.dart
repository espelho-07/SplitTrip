import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo_account.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';

class IpoAccountsView extends StatefulWidget {
  const IpoAccountsView({super.key});

  @override
  State<IpoAccountsView> createState() => _IpoAccountsViewState();
}

class _IpoAccountsViewState extends State<IpoAccountsView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final accounts = ipoVm.accounts;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        elevation: 0,
        title: Text(
          'IPO Accounts & Balances',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.emeraldPrimary),
            tooltip: 'Add Account',
            onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
          ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(height: 12),
                  Text(
                    'No IPO accounts added yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add First Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final acc = accounts[index];
                final metrics = ipoVm.getAccountMetrics(acc.id);
                return _buildAccountCard(context, acc, metrics, ipoVm, isDark);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showAddAccountSheet(context, ipoVm, isDark),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Add New IPO Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    IpoAccount acc,
    Map<String, dynamic> metrics,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final appliedPaise = metrics['totalAppliedPaise'] as int? ?? 0;
    final paidPaise = metrics['totalPaidPaise'] as int? ?? 0;
    final pendingPaise = metrics['totalPendingPaise'] as int? ?? 0;
    final appCount = metrics['applicationCount'] as int? ?? 0;
    final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(acc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          HapticHelper.light();
          _showAccountTimelineSheet(context, acc, metrics, ipoVm, isDark);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: acc.isSelf
                              ? AppColors.emeraldPrimary.withValues(alpha: 0.12)
                              : Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          acc.isSelf ? Icons.person_rounded : Icons.group_rounded,
                          color: acc.isSelf ? AppColors.emeraldPrimary : Colors.blueAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (acc.maskedPan.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 12, color: isDark ? Colors.white54 : Colors.black45),
                                  const SizedBox(width: 4),
                                  Text(
                                    acc.maskedPan,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (!acc.isSelf)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      tooltip: 'Delete Account',
                      onPressed: () => _confirmDeleteAccount(context, acc, ipoVm, isDark),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCol(
                      'Applied',
                      CurrencyFormatter.formatPaise(appliedPaise, currencyCode: 'INR'),
                      isDark ? Colors.white : const Color(0xFF0F172A),
                      isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricCol(
                      'Paid / Blocked',
                      CurrencyFormatter.formatPaise(paidPaise, currencyCode: 'INR'),
                      AppColors.emeraldPrimary,
                      isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricCol(
                      'Pending',
                      CurrencyFormatter.formatPaise(pendingPaise, currencyCode: 'INR'),
                      pendingPaise > 0 ? Colors.amber.shade700 : (isDark ? Colors.white54 : Colors.black45),
                      isDark,
                    ),
                  ),
                ],
              ),
              if (availableCreditPaise > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.2), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emeraldPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Available Credit: ${CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$appCount ${appCount == 1 ? 'application' : 'applications'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color valueColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showAddAccountSheet(BuildContext context, IpoViewModel ipoVm, bool isDark) {
    HapticHelper.light();
    final nameCtrl = TextEditingController();
    final panCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final upiCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add IPO Application Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save family or friend accounts to easily apply for IPOs on their behalf.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Account Nickname *',
                  hintText: 'e.g. Brother, Papa, Friend',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: panCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'PAN Number (Optional, Securely Masked)',
                  hintText: 'e.g. ABCDE1234F',
                  helperText: 'Only last 4 digits are visible in the app for safety',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holderCtrl,
                decoration: InputDecoration(
                  labelText: 'Account Holder Full Name (Optional)',
                  hintText: 'As per bank account',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiCtrl,
                decoration: InputDecoration(
                  labelText: 'UPI ID (Optional)',
                  hintText: 'e.g. name@okhdfcbank',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    Navigator.pop(ctx);
                    await ipoVm.createAccount(
                      displayName: name,
                      rawPan: panCtrl.text.trim(),
                      accountHolderName: holderCtrl.text.trim(),
                      upiId: upiCtrl.text.trim(),
                    );
                    HapticHelper.success();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context, IpoAccount acc, IpoViewModel ipoVm, bool isDark) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        title: Text('Delete ${acc.displayName}?'),
        content: const Text('This will remove the account from your quick selection list. Previous applications will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ipoVm.deleteAccount(acc.id);
              HapticHelper.medium();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAccountTimelineSheet(
    BuildContext context,
    IpoAccount acc,
    Map<String, dynamic> metrics,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final apps = (metrics['applications'] as List<IpoApplication>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${acc.displayName} • IPO History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (acc.maskedPan.isNotEmpty)
                            Text(
                              'PAN: ${acc.maskedPan}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (apps.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No IPO applications recorded for ${acc.displayName} yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        itemCount: apps.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final app = apps[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        app.ipoName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(app.status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        app.status.displayName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(app.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${app.lotsApplied} Lots (${app.totalSharesApplied} Shares) @ ₹${app.bidPriceInRupees}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormatter.formatDate(app.applicationDate),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                    if (app.status == IpoApplicationStatus.allotted)
                                      Text(
                                        'Invested: ${CurrencyFormatter.formatPaise(app.actualInvestedAmountInPaise ?? app.applicationAmountInPaise, currencyCode: 'INR')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.emeraldPrimary,
                                        ),
                                      )
                                    else if (app.status == IpoApplicationStatus.notAllotted || app.status == IpoApplicationStatus.refunded)
                                      Text(
                                        'Refunded: ${CurrencyFormatter.formatPaise(app.releasedAmountInPaise ?? app.applicationAmountInPaise, currencyCode: 'INR')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(IpoApplicationStatus status) {
    switch (status) {
      case IpoApplicationStatus.allotted:
        return AppColors.emeraldPrimary;
      case IpoApplicationStatus.applied:
      case IpoApplicationStatus.fundsBlocked:
        return Colors.blueAccent;
      case IpoApplicationStatus.notAllotted:
      case IpoApplicationStatus.refunded:
        return Colors.purpleAccent;
      case IpoApplicationStatus.partiallyAllotted:
        return Colors.amber.shade700;
      case IpoApplicationStatus.listed:
        return Colors.teal;
    }
  }
}
