import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../../domain/models/ipo/ipo_account.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ipo_viewmodel.dart';

class IpoApplyView extends StatefulWidget {
  final Ipo ipo;
  final IpoApplication? existingApplication;

  const IpoApplyView({
    super.key,
    required this.ipo,
    this.existingApplication,
  });

  @override
  State<IpoApplyView> createState() => _IpoApplyViewState();
}

class _AccountApplicationConfig {
  final IpoAccount account;
  int lots;
  late TextEditingController paidController;

  _AccountApplicationConfig({
    required this.account,
    this.lots = 1,
    String initialPaidRupees = '0',
  }) {
    paidController = TextEditingController(text: initialPaidRupees);
  }
}

class _ContributorEntry {
  String name;
  String? userId;
  final TextEditingController controller;

  _ContributorEntry({
    required this.name,
    this.userId,
    required this.controller,
  });
}

class _IpoApplyViewState extends State<IpoApplyView> {
  late TextEditingController _bidPriceController;
  late TextEditingController _notesController;
  final Map<String, _AccountApplicationConfig> _selectedAccounts = {};
  final List<_ContributorEntry> _contributors = [];

  @override
  void initState() {
    super.initState();
    final app = widget.existingApplication;
    _bidPriceController = TextEditingController(
      text: app != null ? app.bidPriceInRupees.toString() : widget.ipo.maxPrice.toString(),
    );
    _notesController = TextEditingController(text: app?.notes ?? '');

    // Initialize with primary "Me" account or existing app's account
    final initialLots = app?.lotsApplied ?? 1;
    final ipoVm = context.read<IpoViewModel>();
    final accounts = ipoVm.accounts;
    final defaultAcc = accounts.isNotEmpty
        ? (app?.applicationAccountId != null
            ? accounts.firstWhere((a) => a.id == app!.applicationAccountId, orElse: () => accounts.first)
            : accounts.first)
        : IpoAccount.self();

    final totalRequiredRupees = (initialLots * widget.ipo.lotSize * (int.tryParse(_bidPriceController.text.trim()) ?? widget.ipo.maxPrice)).toString();

    _selectedAccounts[defaultAcc.id] = _AccountApplicationConfig(
      account: defaultAcc,
      lots: initialLots,
      initialPaidRupees: totalRequiredRupees,
    );

    if (app != null && app.fundings.isNotEmpty) {
      for (final f in app.fundings.where((f) => !f.isSelf)) {
        _contributors.add(_ContributorEntry(
          name: f.personName ?? 'Friend',
          userId: f.personUserId,
          controller: TextEditingController(text: (f.amountInPaise / 100.0).toStringAsFixed(0)),
        ));
      }
    }
  }

  @override
  void dispose() {
    _bidPriceController.dispose();
    _notesController.dispose();
    for (final cfg in _selectedAccounts.values) {
      cfg.paidController.dispose();
    }
    for (final c in _contributors) {
      c.controller.dispose();
    }
    super.dispose();
  }

  int get _bidPrice => int.tryParse(_bidPriceController.text.trim()) ?? widget.ipo.maxPrice;

  int _calculateAccountAmountPaise(int lots) {
    return IpoApplication.calculateApplicationAmountPaise(
      lots: lots,
      lotSize: widget.ipo.lotSize,
      bidPriceRupees: _bidPrice,
    );
  }

  int get _grandTotalApplicationAmountPaise {
    return _selectedAccounts.values.fold<int>(
      0,
      (sum, cfg) => sum + _calculateAccountAmountPaise(cfg.lots),
    );
  }

  void _toggleAccount(IpoAccount account) {
    setState(() {
      if (_selectedAccounts.containsKey(account.id)) {
        if (_selectedAccounts.length > 1) {
          _selectedAccounts.remove(account.id)?.paidController.dispose();
        }
      } else {
        final amountPaise = _calculateAccountAmountPaise(1);
        _selectedAccounts[account.id] = _AccountApplicationConfig(
          account: account,
          lots: 1,
          initialPaidRupees: (amountPaise / 100.0).toStringAsFixed(0),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final allAccounts = ipoVm.accounts;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'I Applied',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // IPO Context Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.ipo.marketType.displayName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.ipo.symbol,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.ipo.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lot Size: ${widget.ipo.lotSize} Shares • Price Band: ${widget.ipo.priceBandFormatted}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 1. Account Selection (Multi-Account)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1. SELECT APPLICATION ACCOUNTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/ipo-accounts'),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allAccounts.map((acc) {
              final isSelected = _selectedAccounts.containsKey(acc.id);
              return FilterChip(
                selected: isSelected,
                label: Text(
                  acc.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected
                        ? (isDark ? AppColors.darkBackground : Colors.white)
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
                selectedColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                checkmarkColor: isDark ? AppColors.darkBackground : Colors.white,
                backgroundColor: isDark ? const Color(0xFF1E252D) : const Color(0xFFF1F5F9),
                onSelected: (_) => _toggleAccount(acc),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 2. Application & Bid Configuration
          Text(
            '2. BID & LOT CONFIGURATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Bid Price Field
          TextField(
            controller: _bidPriceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Bid / Cut-off Price per Share',
              helperText: 'Default is cutoff (₹${widget.ipo.maxPrice})',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 14),

          // Per-Account Lots Configuration Cards
          ..._selectedAccounts.values.map((cfg) {
            final accAmountPaise = _calculateAccountAmountPaise(cfg.lots);
            final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(cfg.account.id);
            final remainingNeededPaise = (accAmountPaise - availableCreditPaise).clamp(0, accAmountPaise);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                      Row(
                        children: [
                          Icon(
                            cfg.account.isSelf ? Icons.person_rounded : Icons.group_rounded,
                            size: 18,
                            color: AppColors.emeraldPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cfg.account.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (cfg.account.maskedPan.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${cfg.account.maskedPan})',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(accAmountPaise, currencyCode: 'INR'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lots: ${cfg.lots} (${cfg.lots * widget.ipo.lotSize} shares)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton.outlined(
                            icon: const Icon(Icons.remove_rounded, size: 16),
                            onPressed: cfg.lots > 1
                                ? () {
                                    setState(() {
                                      cfg.lots--;
                                    });
                                  }
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text('${cfg.lots}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            onPressed: () {
                              setState(() {
                                cfg.lots++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (availableCreditPaise > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.emeraldPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'Eligible Reusable Credit: ${CurrencyFormatter.formatPaise(availableCreditPaise, currencyCode: 'INR')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Additional Amount Needed: ${CurrencyFormatter.formatPaise(remainingNeededPaise, currencyCode: 'INR')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: remainingNeededPaise > 0 ? Colors.amber.shade700 : AppColors.emeraldPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 14),

          // Total Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Applications Required',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                    Text(
                      '${_selectedAccounts.length} Account(s) • ${_selectedAccounts.values.fold<int>(0, (s, c) => s + c.lots)} Lots Total',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatPaise(_grandTotalApplicationAmountPaise, currencyCode: 'INR'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Personal Notes (Optional)',
              hintText: 'e.g. Applied via Zerodha UPI mandate',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveApplications,
              child: Text(
                'Save ${_selectedAccounts.length == 1 ? 'Application' : '${_selectedAccounts.length} Applications'} & Update Ledger',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveApplications() async {
    HapticHelper.medium();
    final authVm = context.read<AuthViewModel>();
    final ipoVm = context.read<IpoViewModel>();
    final userId = authVm.currentUser?.id ?? 'usr_current';

    final applicationsToSave = <IpoApplication>[];

    for (final cfg in _selectedAccounts.values) {
      final appId = const Uuid().v4();
      final totalAmountPaise = _calculateAccountAmountPaise(cfg.lots);
      final availableCreditPaise = ipoVm.getAccountAvailableCreditPaise(cfg.account.id);

      final fundings = <IpoFunding>[
        IpoFunding(
          id: const Uuid().v4(),
          applicationId: appId,
          funderType: cfg.account.isSelf ? IpoFunderType.self : IpoFunderType.person,
          personName: cfg.account.isSelf ? null : cfg.account.displayName,
          amountInPaise: totalAmountPaise,
        ),
      ];

      final coveredFromCredit = availableCreditPaise >= totalAmountPaise ? totalAmountPaise : availableCreditPaise;
      final remainingNeeded = totalAmountPaise - coveredFromCredit;

      final app = IpoApplication(
        id: appId,
        ipoId: widget.ipo.id,
        ipoName: widget.ipo.name,
        userId: userId,
        applicationAccountId: cfg.account.id,
        accountDisplayName: cfg.account.displayName,
        accountMaskedPan: cfg.account.maskedPan,
        applicationDate: DateTime.now(),
        lotsApplied: cfg.lots,
        lotSize: widget.ipo.lotSize,
        bidPriceInRupees: _bidPrice,
        applicationAmountInPaise: totalAmountPaise,
        paidAmountInPaise: coveredFromCredit,
        remainingAmountInPaise: remainingNeeded,
        fundings: fundings,
        status: IpoApplicationStatus.applied,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      applicationsToSave.add(app);
    }

    await ipoVm.recordMultipleApplications(applicationsToSave);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${applicationsToSave.length} application(s) for ${widget.ipo.name} saved!'),
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
      context.pop();
    }
  }
}
