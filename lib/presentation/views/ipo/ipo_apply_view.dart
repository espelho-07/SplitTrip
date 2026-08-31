import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/kith_calculator_engine.dart';
import '../../../core/widgets/kith_amount_calculator_field.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ipo_viewmodel.dart';
import '../../viewmodels/personal_expense_viewmodel.dart';

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
  late int _lotsApplied;
  late TextEditingController _bidPriceController;
  late TextEditingController _selfAmountController;
  late TextEditingController _notesController;
  final List<_ContributorEntry> _contributors = [];

  @override
  void initState() {
    super.initState();
    final app = widget.existingApplication;
    _lotsApplied = app?.lotsApplied ?? 1;
    _bidPriceController = TextEditingController(
      text: app != null ? app.bidPriceInRupees.toString() : widget.ipo.maxPrice.toString(),
    );
    _notesController = TextEditingController(text: app?.notes ?? '');

    final initialTotalPaise = IpoApplication.calculateApplicationAmountPaise(
      lots: _lotsApplied,
      lotSize: widget.ipo.lotSize,
      bidPriceRupees: int.tryParse(_bidPriceController.text.trim()) ?? widget.ipo.maxPrice,
    );

    if (app != null && app.fundings.isNotEmpty) {
      final selfFunding = app.fundings.firstWhere((f) => f.isSelf, orElse: () => const IpoFunding(id: '', applicationId: '', funderType: IpoFunderType.self, amountInPaise: 0));
      _selfAmountController = TextEditingController(
        text: (selfFunding.amountInPaise / 100.0).toStringAsFixed(0),
      );

      for (final f in app.fundings.where((f) => !f.isSelf)) {
        _contributors.add(_ContributorEntry(
          name: f.personName ?? 'Friend',
          userId: f.personUserId,
          controller: TextEditingController(text: (f.amountInPaise / 100.0).toStringAsFixed(0)),
        ));
      }
    } else {
      _selfAmountController = TextEditingController(
        text: (initialTotalPaise / 100.0).toStringAsFixed(0),
      );
    }
  }

  @override
  void dispose() {
    _bidPriceController.dispose();
    _selfAmountController.dispose();
    _notesController.dispose();
    for (final c in _contributors) {
      c.controller.dispose();
    }
    super.dispose();
  }

  int get _bidPrice => int.tryParse(_bidPriceController.text.trim()) ?? widget.ipo.maxPrice;

  int get _totalApplicationAmountPaise {
    return IpoApplication.calculateApplicationAmountPaise(
      lots: _lotsApplied,
      lotSize: widget.ipo.lotSize,
      bidPriceRupees: _bidPrice,
    );
  }

  int get _selfAmountPaise {
    return KithCalculatorEngine.evaluateToPaise(_selfAmountController.text.trim());
  }

  int get _totalAllocatedPaise {
    int total = _selfAmountPaise;
    for (final c in _contributors) {
      total += KithCalculatorEngine.evaluateToPaise(c.controller.text.trim());
    }
    return total;
  }

  void _recalculateSelfAmountOnLotChange() {
    if (_contributors.isEmpty) {
      final total = _totalApplicationAmountPaise;
      _selfAmountController.text = (total / 100.0).toStringAsFixed(0);
    }
  }

  void _addContributorModal() {
    HapticHelper.light();
    final personalVm = context.read<PersonalExpenseViewModel>();
    final knownPeople = personalVm.debtsSummary.debts
        .map((d) => d.personName.trim())
        .where((n) => n.isNotEmpty && !_contributors.any((c) => c.name.toLowerCase() == n.toLowerCase()))
        .toSet()
        .toList();

    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add Contributor',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Friend / Contributor Name',
                  hintText: 'e.g. Rohit, Priya, Rahul',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (knownPeople.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Recent People:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: knownPeople.map((name) {
                    return ActionChip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addContributor(name);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  _addContributor(name);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addContributor(String name) {
    setState(() {
      _contributors.add(_ContributorEntry(
        name: name,
        controller: TextEditingController(text: '0'),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAppPaise = _totalApplicationAmountPaise;
    final totalAllocPaise = _totalAllocatedPaise;
    final diffPaise = totalAppPaise - totalAllocPaise;
    final isExactMatch = diffPaise == 0;

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

          // Application Details Form
          Text(
            '1. APPLICATION DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Lots Selector
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lots Applied',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_lotsApplied * widget.ipo.lotSize} Shares (${widget.ipo.lotSize} per lot)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: _lotsApplied > 1
                          ? () {
                              setState(() {
                                _lotsApplied--;
                                _recalculateSelfAmountOnLotChange();
                              });
                            }
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_lotsApplied',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _lotsApplied++;
                          _recalculateSelfAmountOnLotChange();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bid Price Field
          TextField(
            controller: _bidPriceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _recalculateSelfAmountOnLotChange()),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Bid / Cut-off Price per Share',
              helperText: 'Default is cutoff (₹${widget.ipo.maxPrice})',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 16),

          // Total Application Amount Display
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
                      'Total Application Amount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                    Text(
                      '$_lotsApplied Lots × ${widget.ipo.lotSize} Shares × ₹$_bidPrice',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatPaise(totalAppPaise, currencyCode: 'INR'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Who funded this IPO Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2. WHO FUNDED THIS IPO?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              TextButton.icon(
                onPressed: _addContributorModal,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Friend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Me (Self Contributor)
          Container(
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded, size: 16, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Me (My Contribution)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                KithAmountCalculatorField(
                  controller: _selfAmountController,
                  currencyCode: 'INR',
                  onAmountChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          // Peer Contributors List
          ..._contributors.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
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
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group_rounded, size: 16, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _contributors.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    KithAmountCalculatorField(
                      controller: item.controller,
                      currencyCode: 'INR',
                      onAmountChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 14),

          // Live Funding Allocation Validation Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExactMatch
                  ? (isDark ? const Color(0xFF132A22) : const Color(0xFFE8F5E9))
                  : (diffPaise > 0
                      ? (isDark ? const Color(0xFF2C2411) : const Color(0xFFFEF3C7))
                      : (isDark ? const Color(0xFF2E1719) : const Color(0xFFFFE4E6))),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExactMatch
                    ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                    : (diffPaise > 0 ? Colors.amber : Colors.redAccent),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExactMatch
                      ? Icons.check_circle_rounded
                      : (diffPaise > 0 ? Icons.info_outline_rounded : Icons.warning_amber_rounded),
                  color: isExactMatch
                      ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                      : (diffPaise > 0 ? Colors.amber : Colors.redAccent),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExactMatch
                            ? 'Funding matches application amount perfectly!'
                            : (diffPaise > 0
                                ? '₹${CurrencyFormatter.formatPaise(diffPaise.abs(), currencyCode: 'INR')} remaining to allocate'
                                : 'Funding exceeds application amount by ₹${CurrencyFormatter.formatPaise(diffPaise.abs(), currencyCode: 'INR')}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isExactMatch
                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                              : (diffPaise > 0 ? Colors.amber : Colors.redAccent),
                        ),
                      ),
                      Text(
                        'Total Allocated: ${CurrencyFormatter.formatPaise(totalAllocPaise, currencyCode: 'INR')} / ${CurrencyFormatter.formatPaise(totalAppPaise, currencyCode: 'INR')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
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
                backgroundColor: isExactMatch
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                    : (isDark ? const Color(0xFF2C3238) : const Color(0xFFCBD5E1)),
                foregroundColor: isExactMatch
                    ? (isDark ? AppColors.darkBackground : Colors.white)
                    : const Color(0xFF64748B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isExactMatch ? _saveApplication : null,
              child: const Text(
                'Save Application & Update Ledger',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveApplication() async {
    HapticHelper.medium();
    final authVm = context.read<AuthViewModel>();
    final ipoVm = context.read<IpoViewModel>();
    final userId = authVm.currentUser?.id ?? 'usr_current';
    final appId = widget.existingApplication?.id ?? const Uuid().v4();

    final fundings = <IpoFunding>[
      IpoFunding(
        id: const Uuid().v4(),
        applicationId: appId,
        funderType: IpoFunderType.self,
        amountInPaise: _selfAmountPaise,
      ),
    ];

    for (final c in _contributors) {
      final amt = KithCalculatorEngine.evaluateToPaise(c.controller.text.trim());
      if (amt > 0) {
        fundings.add(IpoFunding(
          id: const Uuid().v4(),
          applicationId: appId,
          funderType: IpoFunderType.person,
          personName: c.name,
          personUserId: c.userId,
          amountInPaise: amt,
        ));
      }
    }

    final application = IpoApplication(
      id: appId,
      ipoId: widget.ipo.id,
      ipoName: widget.ipo.name,
      userId: userId,
      applicationDate: DateTime.now(),
      lotsApplied: _lotsApplied,
      lotSize: widget.ipo.lotSize,
      bidPriceInRupees: _bidPrice,
      applicationAmountInPaise: _totalApplicationAmountPaise,
      fundings: fundings,
      status: IpoApplicationStatus.applied,
      notes: _notesController.text.trim(),
      createdAt: widget.existingApplication?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ipoVm.recordApplication(application);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application for ${widget.ipo.name} saved!'),
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
      context.pop();
    }
  }
}
