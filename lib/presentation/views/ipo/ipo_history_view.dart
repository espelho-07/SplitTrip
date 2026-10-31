import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';
import 'widgets/ipo_allotment_sheet.dart';

class IpoHistoryView extends StatefulWidget {
  const IpoHistoryView({super.key});

  @override
  State<IpoHistoryView> createState() => _IpoHistoryViewState();
}

class _IpoHistoryViewState extends State<IpoHistoryView> {
  String _selectedStatusFilter = 'all'; // all, allotted, notAllotted, refunded, pending
  String? _selectedAccountId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color forestGreen = Color(0xFF0E3E28);
  static const Color darkGreenText = Color(0xFF15803D);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final allApps = ipoVm.applications;
    final accounts = ipoVm.accounts;

    // Filter applications
    final filteredApps = allApps.where((app) {
      // 1. Status Filter
      if (_selectedStatusFilter == 'allotted') {
        if (app.status != IpoApplicationStatus.allotted && app.status != IpoApplicationStatus.partiallyAllotted) {
          return false;
        }
      } else if (_selectedStatusFilter == 'notAllotted') {
        if (app.status != IpoApplicationStatus.notAllotted) return false;
      } else if (_selectedStatusFilter == 'refunded') {
        if (app.status != IpoApplicationStatus.refundCredited && app.status != IpoApplicationStatus.refundInitiated) {
          return false;
        }
      } else if (_selectedStatusFilter == 'pending') {
        if (app.isTerminalState) return false;
      }

      // 2. Account Filter
      if (_selectedAccountId != null && app.applicationAccountId != _selectedAccountId) {
        return false;
      }

      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = app.ipoName.toLowerCase().contains(query);
        final matchesAcc = app.accountName.toLowerCase().contains(query);
        if (!matchesName && !matchesAcc) return false;
      }

      return true;
    }).toList();

    // Sort by most recent application first
    filteredApps.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));

    // Calculate historical statistics
    final totalApplications = allApps.length;
    final terminalApps = allApps.where((a) => a.isTerminalState).toList();
    final allottedApps = allApps.where((a) => a.isAllotted).toList();
    final successRate = terminalApps.isNotEmpty
        ? ((allottedApps.length / terminalApps.length) * 100).toStringAsFixed(1)
        : '0.0';

    final totalInvestedPaise = ipoVm.totalInvestedPaise;
    final totalBlockedPaise = ipoVm.totalBlockedPaise;
    final totalPendingRefundPaise = ipoVm.totalPendingRefundPaise;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'IPO History & Ledger',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // 1. Performance & Allotment Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HISTORICAL PERFORMANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Success Rate: $successRate%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Applications', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54)),
                          const SizedBox(height: 3),
                          Text('$totalApplications Total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          Text('${allottedApps.length} Allotted', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Invested', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54)),
                          const SizedBox(height: 3),
                          Text(
                            CurrencyFormatter.formatPaise(totalInvestedPaise, currencyCode: 'INR'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF10B981) : darkGreenText,
                            ),
                          ),
                          Text('Allotments debited', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black45)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Blocked', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54)),
                          const SizedBox(height: 3),
                          Text(
                            CurrencyFormatter.formatPaise(totalBlockedPaise, currencyCode: 'INR'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                          ),
                          if (totalPendingRefundPaise > 0)
                            Text(
                              'Refund: ${CurrencyFormatter.formatPaise(totalPendingRefundPaise, currencyCode: 'INR')}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                            )
                          else
                            Text('In active bids', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Search & Account Filter Row
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by IPO or Demat Account…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('all', 'All Applications (${allApps.length})', isDark),
                const SizedBox(width: 8),
                _buildStatusChip('allotted', 'Allotted (${allottedApps.length})', isDark),
                const SizedBox(width: 8),
                _buildStatusChip('notAllotted', 'Not Allotted', isDark),
                const SizedBox(width: 8),
                _buildStatusChip('refunded', 'Refunded', isDark),
                const SizedBox(width: 8),
                _buildStatusChip('pending', 'Active / Mandate', isDark),
              ],
            ),
          ),

          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Accounts'),
                    selected: _selectedAccountId == null,
                    selectedColor: isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFDCFCE7),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _selectedAccountId == null ? (isDark ? const Color(0xFF10B981) : darkGreenText) : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedAccountId = null;
                        });
                      }
                    },
                  ),
                  for (final acc in accounts) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(acc.displayName),
                      selected: _selectedAccountId == acc.id,
                      selectedColor: isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFDCFCE7),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedAccountId == acc.id ? (isDark ? const Color(0xFF10B981) : darkGreenText) : (isDark ? Colors.white60 : Colors.black54),
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedAccountId = val ? acc.id : null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 4. Applications List
          if (filteredApps.isEmpty)
            _buildEmptyHistory(isDark)
          else
            ...filteredApps.map((app) => _buildApplicationHistoryCard(context, app, ipoVm, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDark ? const Color(0xFF10B981) : forestGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      onSelected: (val) {
        if (val) {
          HapticHelper.selection();
          setState(() {
            _selectedStatusFilter = filterKey;
          });
        }
      },
    );
  }

  Widget _buildApplicationHistoryCard(BuildContext context, IpoApplication app, IpoViewModel ipoVm, bool isDark) {
    final isAllotted = app.isAllotted;
    final isTerminal = app.isTerminalState;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAllotted
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isAllotted ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticHelper.light();
            _showApplicationDetails(context, app, ipoVm, isDark);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: IPO Name + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.ipoName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${app.accountName} ${(app.accountMaskedPan?.isNotEmpty ?? false) ? "• ${app.accountMaskedPan}" : ""} • ${DateFormatter.formatShortDate(app.applicationDate)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(app.status),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  height: 0.8,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 10),

                // Financial Breakdown Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bids / Lots', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
                          const SizedBox(height: 2),
                          Text(
                            '${app.lotsApplied} Lot (${app.lotsApplied * app.lotSize} Shares)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isTerminal ? 'Debited / Invested' : 'Mandate Amount', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatPaise(
                              isAllotted ? app.actualAllottedAmountInPaise : app.applicationAmountInPaise,
                              currencyCode: 'INR',
                            ),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isAllotted
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (app.outstandingRefundInPaise > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Refund Pending', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B))),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(app.outstandingRefundInPaise, currencyCode: 'INR'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (app.refundCreditedAmountInPaise > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Refund Credited', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(app.refundCreditedAmountInPaise, currencyCode: 'INR'),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(IpoApplicationStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case IpoApplicationStatus.allotted:
      case IpoApplicationStatus.listed:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case IpoApplicationStatus.partiallyAllotted:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case IpoApplicationStatus.notAllotted:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case IpoApplicationStatus.fundsBlocked:
      case IpoApplicationStatus.mandateApproved:
      case IpoApplicationStatus.submitted:
      case IpoApplicationStatus.applied:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case IpoApplicationStatus.mandatePending:
      case IpoApplicationStatus.planned:
      case IpoApplicationStatus.draft:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case IpoApplicationStatus.refundPending:
      case IpoApplicationStatus.refundInitiated:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        break;
      case IpoApplicationStatus.refunded:
      case IpoApplicationStatus.refundCredited:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      case IpoApplicationStatus.rejected:
      case IpoApplicationStatus.cancelled:
      case IpoApplicationStatus.mandateFailed:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No applications match your filter',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Plan an application from the IPO Manager to start tracking.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplicationDetails(BuildContext context, IpoApplication app, IpoViewModel ipoVm, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      app.ipoName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _buildStatusBadge(app.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Account: ${app.accountDisplayName} (${app.accountMaskedPan})',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildDetailRow('Applied Lots', '${app.lotsApplied} Lots (${app.lotsApplied * app.lotSize} shares)', isDark),
              _buildDetailRow('Bid Price', '₹${app.bidPriceInRupees}', isDark),
              _buildDetailRow('Total Mandate Amount', CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR'), isDark),
              _buildDetailRow('Current Blocked Amount', CurrencyFormatter.formatPaise(app.currentBlockedAmountInPaise, currencyCode: 'INR'), isDark),
              _buildDetailRow('Debited Allotment Amount', CurrencyFormatter.formatPaise(app.actualAllottedAmountInPaise, currencyCode: 'INR'), isDark),
              _buildDetailRow('Refund Amount', CurrencyFormatter.formatPaise(app.refundCreditedAmountInPaise, currencyCode: 'INR'), isDark),
              if (app.notes != null && app.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Notes: ${app.notes}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black54)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        IpoAllotmentSheet.show(context, app);
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Update Status'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/ipo/${app.ipoId}');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View IPO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
