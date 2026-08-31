import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../viewmodels/ipo_viewmodel.dart';

class IpoHomeView extends StatefulWidget {
  const IpoHomeView({super.key});

  @override
  State<IpoHomeView> createState() => _IpoHomeViewState();
}

class _IpoHomeViewState extends State<IpoHomeView> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IpoViewModel>().loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final ipos = ipoVm.filteredIpos;

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
          'IPO Money Manager',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              HapticHelper.light();
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  ipoVm.setSearchQuery('');
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ipoVm.loadData(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          children: [
            // Optional Search Bar
            if (_isSearchOpen) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: ipoVm.setSearchQuery,
                  decoration: const InputDecoration(
                    hintText: 'Search by IPO name, symbol, or company…',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],

            // Filter Tabs Row (Open, Upcoming, Closed, My IPOs, Listed)
            _buildTabSelector(ipoVm, isDark),

            const SizedBox(height: 12),

            // Market Type Chips (All, Mainboard, SME)
            _buildMarketFilterRow(ipoVm, isDark),

            const SizedBox(height: 16),

            // Summary Card (Only on My IPOs tab)
            if (ipoVm.selectedTab == 'my_ipos') ...[
              _buildMyIposSummaryCard(ipoVm, isDark),
              const SizedBox(height: 16),
            ],

            // IPO Listings Count & Last Updated Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ipos.length} ${ipoVm.selectedTab.toUpperCase().replaceAll('_', ' ')} IPOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                if (ipoVm.lastUpdated != null)
                  Text(
                    'Updated ${DateFormatter.formatRelative(ipoVm.lastUpdated!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // IPO Feed
            if (ipos.isEmpty)
              _buildEmptyState(isDark, ipoVm)
            else
              ...ipos.map((ipo) => _buildIpoCard(context, ipo, ipoVm, isDark)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(IpoViewModel ipoVm, bool isDark) {
    final tabs = [
      {'id': 'open', 'label': 'Open Now', 'count': ipoVm.openCount},
      {'id': 'upcoming', 'label': 'Upcoming', 'count': ipoVm.upcomingCount},
      {'id': 'closed', 'label': 'Closed', 'count': ipoVm.closedCount},
      {'id': 'my_ipos', 'label': 'My IPOs', 'count': ipoVm.myIposCount},
      {'id': 'listed', 'label': 'Listed', 'count': ipoVm.listedCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final id = tab['id'] as String;
          final label = tab['label'] as String;
          final count = tab['count'] as int;
          final isSelected = ipoVm.selectedTab == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.black26 : Colors.white24)
                            : (isDark ? Colors.white12 : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                HapticHelper.selection();
                ipoVm.setTab(id);
              },
              selectedColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
              backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppColors.darkBackground : Colors.white)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarketFilterRow(IpoViewModel ipoVm, bool isDark) {
    return Row(
      children: [
        _buildFilterPill(
          label: 'All Markets',
          isSelected: ipoVm.selectedMarketFilter == null,
          isDark: isDark,
          onTap: () => ipoVm.setMarketFilter(null),
        ),
        const SizedBox(width: 8),
        _buildFilterPill(
          label: 'Mainboard',
          isSelected: ipoVm.selectedMarketFilter == IpoMarketType.mainboard,
          isDark: isDark,
          onTap: () => ipoVm.setMarketFilter(IpoMarketType.mainboard),
        ),
        const SizedBox(width: 8),
        _buildFilterPill(
          label: 'SME',
          isSelected: ipoVm.selectedMarketFilter == IpoMarketType.sme,
          isDark: isDark,
          onTap: () => ipoVm.setMarketFilter(IpoMarketType.sme),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticHelper.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMyIposSummaryCard(IpoViewModel ipoVm, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Text(
                'MY IPOS PORTFOLIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ipoVm.applications.length} Applications',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
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
                    Text(
                      'Funds Blocked',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(ipoVm.totalBlockedPaise, currencyCode: 'INR'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invested (Allotted)',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(ipoVm.totalInvestedPaise, currencyCode: 'INR'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Released / Refunded',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(ipoVm.totalReleasedPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (ipoVm.totalUnrealizedPnlPaise != 0) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unrealized P&L',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ipoVm.totalUnrealizedPnlPaise > 0 ? '+' : ''}${CurrencyFormatter.formatPaise(ipoVm.totalUnrealizedPnlPaise, currencyCode: 'INR')}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ipoVm.totalUnrealizedPnlPaise > 0
                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                              : (isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIpoCard(BuildContext context, Ipo ipo, IpoViewModel ipoVm, bool isDark) {
    final application = ipoVm.getApplicationForIpo(ipo.id);
    final isApplied = application != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            context.push('/ipo/${ipo.id}');
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isApplied
                    ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.5)
                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                width: isApplied ? 1.2 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tags Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ipo.marketType.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ipo.symbol,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ipo.isBiddingActive
                            ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ipo.status.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ipo.isBiddingActive
                              ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Name & Company
                Text(
                  ipo.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ipo.companyName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                const SizedBox(height: 12),

                // Numbers Grid
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price Band',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          Text(
                            ipo.priceBandFormatted,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Min. Investment',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          Text(
                            '₹${CurrencyFormatter.formatPaise(ipo.minInvestmentRupees * 100, currencyCode: 'INR')}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lot Size',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          Text(
                            '${ipo.lotSize} Shares',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Optional GMP / Subscription Pills Row
                if (ipo.gmp != null || ipo.subscriptionOverall != null || isApplied) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (isApplied)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                              const SizedBox(width: 4),
                              Text(
                                'Applied • ${application.lotsApplied} Lots (${CurrencyFormatter.formatPaise(application.applicationAmountInPaise, currencyCode: 'INR')})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (ipo.gmp != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'GMP: ~₹${ipo.gmp} (Indicative)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                            ),
                          ),
                        ),
                      if (ipo.subscriptionOverall != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${ipo.subscriptionOverall}x Subscribed',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, IpoViewModel ipoVm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No IPOs found in this category',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh live market feeds',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
