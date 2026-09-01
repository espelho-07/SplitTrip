import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../data/services/p2p_sync_service.dart';
import '../../../data/services/sync_service.dart';
import '../../../domain/models/personal_debt.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';
import '../trip/widgets/nearby_sync_sheet.dart';
import 'widgets/add_personal_expense_sheet.dart';
import 'widgets/record_repayment_sheet.dart';

enum DebtFilterType { all, lent, borrowed, settled }
enum LendingViewMode { byPerson, allTransactions }

class LendingBorrowingView extends StatefulWidget {
  const LendingBorrowingView({super.key});

  @override
  State<LendingBorrowingView> createState() => _LendingBorrowingViewState();
}

class _LendingBorrowingViewState extends State<LendingBorrowingView> {
  LendingViewMode _viewMode = LendingViewMode.byPerson;
  DebtFilterType _filter = DebtFilterType.all;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<PersonalExpenseViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final summary = vm.debtsSummary;
    final allDebts = summary.debts;
    final personSummaries = vm.personSummaries;

    final filteredPersons = personSummaries.where((p) {
      if (_filter == DebtFilterType.lent && (p.unsettledLentPaise <= 0 || p.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.borrowed && (p.unsettledBorrowedPaise <= 0 || p.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.settled && !p.isSettled) {
        return false;
      }
      if (_search.trim().isNotEmpty) {
        final query = _search.trim().toLowerCase();
        final matchPerson = p.personName.toLowerCase().contains(query);
        final matchNotes = p.debts.any((d) => d.description?.toLowerCase().contains(query) ?? false);
        if (!matchPerson && !matchNotes) return false;
      }
      return true;
    }).toList();

    final filteredDebts = allDebts.where((d) {
      if (_filter == DebtFilterType.lent && (d.debtType != PersonalDebtType.lent || d.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.borrowed && (d.debtType != PersonalDebtType.borrowed || d.isSettled)) {
        return false;
      }
      if (_filter == DebtFilterType.settled && (!d.isSettled && d.remainingAmountInPaise > 0)) {
        return false;
      }
      if (_search.trim().isNotEmpty) {
        final query = _search.trim().toLowerCase();
        final matchPerson = d.personName.toLowerCase().contains(query);
        final matchNote = d.description?.toLowerCase().contains(query) ?? false;
        if (!matchPerson && !matchNote) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Lending & Borrowing', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering_rounded, size: 22),
            tooltip: 'Sync Nearby (Offline)',
            onPressed: () {
              NearbySyncSheet.show(
                context,
                p2pService: context.read<P2PSyncService>(),
                syncService: context.read<SyncService>(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
            tooltip: 'Add Loan / Borrow',
            onPressed: () {
              AddPersonalExpenseSheet.show(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = authVm.currentUser;
          if (user != null) {
            await vm.loadData(user.id);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SurfaceCard(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Collect',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(summary.totalLentPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Pay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(summary.totalBorrowedPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Balance Position',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      Text(
                        '${summary.netBalancePaise >= 0 ? '+' : ''}${CurrencyFormatter.formatPaise(summary.netBalancePaise, currencyCode: 'INR')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: summary.netBalancePaise >= 0
                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                              : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _viewMode = LendingViewMode.byPerson);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == LendingViewMode.byPerson
                              ? AppColors.emeraldPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 15,
                              color: _viewMode == LendingViewMode.byPerson
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'By Person (${personSummaries.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _viewMode == LendingViewMode.byPerson
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _viewMode == LendingViewMode.byPerson
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _viewMode = LendingViewMode.allTransactions);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == LendingViewMode.allTransactions
                              ? AppColors.emeraldPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 15,
                              color: _viewMode == LendingViewMode.allTransactions
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'All Records (${allDebts.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _viewMode == LendingViewMode.allTransactions
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _viewMode == LendingViewMode.allTransactions
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: _viewMode == LendingViewMode.byPerson
                    ? 'Search person (e.g. Rahul, Rohit)...'
                    : 'Search records by person or note...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(_viewMode == LendingViewMode.byPerson
                        ? 'All (${personSummaries.length})'
                        : 'All (${allDebts.length})'),
                    selected: _filter == DebtFilterType.all,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.all),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('To Collect'),
                    selected: _filter == DebtFilterType.lent,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.lent),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('To Pay'),
                    selected: _filter == DebtFilterType.borrowed,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.borrowed),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Settled'),
                    selected: _filter == DebtFilterType.settled,
                    onSelected: (_) => setState(() => _filter = DebtFilterType.settled),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_viewMode == LendingViewMode.byPerson) ...[
              if (filteredPersons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: EmptyStateView(
                    emoji: '👥',
                    title: 'No people found',
                    subtitle: _search.isNotEmpty
                        ? 'No person matched "$_search".'
                        : 'You do not have any lending relationships recorded yet.',
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPersons.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (ctx, i) {
                    final p = filteredPersons[i];
                    final isOwed = p.netBalancePaise > 0;

                    return SurfaceCard(
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: InkWell(
                        onTap: () {
                          HapticHelper.light();
                          context.push('/person-ledger?name=${Uri.encodeComponent(p.personName)}');
                        },
                        borderRadius: AppRadius.mdBorder,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                      child: Text(
                                        p.personName.isNotEmpty ? p.personName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.emeraldPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.personName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.transactionCount} ${p.transactionCount == 1 ? 'transaction' : 'transactions'} · ${DateFormatter.formatRelative(p.lastActivityDate)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (p.isSettled || p.netBalancePaise == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 12, color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Settled',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isOwed
                                          ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15)
                                          : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isOwed ? 'Owes you' : 'You owe',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isOwed
                                                ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                                : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatPaise(p.netBalancePaise.abs(), currencyCode: 'INR'),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isOwed
                                                ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                                : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Lent: ${CurrencyFormatter.formatPaise(p.totalLentPaise, currencyCode: 'INR')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('•', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Borrowed: ${CurrencyFormatter.formatPaise(p.totalBorrowedPaise, currencyCode: 'INR')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('Open Ledger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.emeraldPrimary),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ]
            else ...[
              if (filteredDebts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: EmptyStateView(
                    emoji: '🤝',
                    title: 'No debt records found',
                    subtitle: _search.isNotEmpty
                        ? 'No lending or borrowing records matched "$_search".'
                        : 'You do not have any records in this category.',
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDebts.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (ctx, i) {
                    final d = filteredDebts[i];
                    final isLent = d.debtType == PersonalDebtType.lent;
                    final isSettled = d.isSettled || d.remainingAmountInPaise <= 0;
                    final repaidAmount = d.initialAmountInPaise - d.remainingAmountInPaise;
                    final progress = (d.initialAmountInPaise > 0
                            ? (repaidAmount / d.initialAmountInPaise)
                            : 1.0)
                        .clamp(0.0, 1.0);

                    return SurfaceCard(
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isLent
                                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                              : AppColors.emeraldPrimary)
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isLent ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      size: 16,
                                      color: isLent
                                          ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                          : AppColors.emeraldPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.personName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      Text(
                                        isLent ? 'Lent by you' : 'Borrowed by you',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isLent
                                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                              : AppColors.emeraldPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (isSettled)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Paid',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatPaise(d.remainingAmountInPaise, currencyCode: 'INR'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'of ${CurrencyFormatter.formatPaise(d.initialAmountInPaise, currencyCode: 'INR')}',
                                      style: AppTypography.bodySmall(isDark: isDark),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (d.description != null && d.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(d.description!, style: AppTypography.bodyMedium(isDark: isDark)),
                          ],
                          const SizedBox(height: 10),
                          if (!isSettled && repaidAmount > 0) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(progress * 100).round()}% repaid (${CurrencyFormatter.formatPaise(repaidAmount, currencyCode: 'INR')})',
                              style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormatter.formatRelative(d.createdAt),
                                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide(
                                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                        width: 0.8,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13),
                                    label: const Text('Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    onPressed: () {
                                      context.push('/person-ledger?name=${Uri.encodeComponent(d.personName)}');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  if (!isSettled)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.emeraldPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      icon: const Icon(Icons.check_rounded, size: 14),
                                      label: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      onPressed: () {
                                        RecordRepaymentSheet.show(context, debt: d);
                                      },
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                    tooltip: 'Delete Record',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          title: const Text('Delete Record'),
                                          content: Text('Are you sure you want to delete this record with ${d.personName}?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogCtx, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true && context.mounted) {
                                        await vm.deleteDebt(d.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
