import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';

class IpoHomeView extends StatefulWidget {
  final bool isEmbeddedTab;
  const IpoHomeView({super.key, this.isEmbeddedTab = false});

  @override
  State<IpoHomeView> createState() => _IpoHomeViewState();
}

class _IpoHomeViewState extends State<IpoHomeView> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  static const Color forestGreen = Color(0xFF0E3E28);
  static const Color softGreenBadge = Color(0xFFDCFCE7);
  static const Color darkGreenText = Color(0xFF15803D);

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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.isEmbeddedTab,
        leading: widget.isEmbeddedTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onPressed: () => context.pop(),
              ),
        title: Text(
          'IPO Manager',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            tooltip: 'Search',
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
          IconButton(
            icon: Icon(Icons.history_rounded, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            tooltip: 'IPO History & Allotments',
            onPressed: () {
              HapticHelper.light();
              context.push('/ipo-history');
            },
          ),
          IconButton(
            icon: Icon(Icons.account_balance_outlined, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            tooltip: 'Accounts & Balances',
            onPressed: () {
              HapticHelper.light();
              context.push('/ipo-accounts');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ipoVm.loadData(forceRefresh: true),
            color: forestGreen,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                // Optional Search Bar
                if (_isSearchOpen) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: forestGreen.withValues(alpha: 0.4)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: ipoVm.setSearchQuery,
                      decoration: const InputDecoration(
                        hintText: 'Search by IPO name, symbol, company…',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],

                // Portfolio Summary Banner (Total Blocked, Invested, Refund)
                _buildPortfolioSummaryCard(ipoVm, isDark),

                // Segmented Filter Pills (Open Now, Upcoming, Closed, etc.)
                _buildSegmentedTabSelector(ipoVm, isDark),

                const SizedBox(height: 18),

                // Section Subheader: e.g. "Open IPOs" • Updated just now
                _buildSectionHeader(ipoVm, isDark),

                const SizedBox(height: 12),

                // IPO Cards Feed
                if (ipos.isEmpty)
                  _buildEmptyState(isDark, ipoVm)
                else
                  ...ipos.map((ipo) => _buildIpoCard(context, ipo, ipoVm, isDark)),
                const SizedBox(height: 12),
                _buildDataAttributionFooter(isDark, ipoVm),
              ],
            ),
          ),

          // Floating Bottom "+ Add Application" Action Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Center(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticHelper.medium();
                    context.push('/ipo-accounts');
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Application',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabSelector(IpoViewModel ipoVm, bool isDark) {
    final tabs = [
      {'id': 'open', 'label': 'Open Now', 'count': ipoVm.openCount},
      {'id': 'upcoming', 'label': 'Upcoming', 'count': ipoVm.upcomingCount},
      {'id': 'closed', 'label': 'Closed', 'count': ipoVm.closedCount},
      {'id': 'my_ipos', 'label': 'My IPOs', 'count': ipoVm.myIposCount},
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
            child: GestureDetector(
              onTap: () {
                HapticHelper.selection();
                ipoVm.setTab(id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF10B981) : forestGreen)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: forestGreen.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.2))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(IpoViewModel ipoVm, bool isDark) {
    String title = 'Open IPOs';
    if (ipoVm.selectedTab == 'upcoming') title = 'Upcoming IPOs';
    if (ipoVm.selectedTab == 'closed') title = 'Closed IPOs';
    if (ipoVm.selectedTab == 'my_ipos') title = 'My Applications';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Row(
          children: [
            Text(
              'Updated just now',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIpoCard(BuildContext context, Ipo ipo, IpoViewModel ipoVm, bool isDark) {
    final applications = ipoVm.getAllApplicationsForIpo(ipo.id);
    final isApplied = applications.isNotEmpty;

    String dateText = '';
    if (ipo.dynamicStatus == IpoStatus.open) {
      dateText = 'Closes ${DateFormatter.formatShortDate(ipo.closeDate)}';
    } else if (ipo.dynamicStatus == IpoStatus.upcoming) {
      dateText = 'Opens ${DateFormatter.formatShortDate(ipo.openDate)}';
    } else {
      dateText = 'Closed ${DateFormatter.formatShortDate(ipo.closeDate)}';
    }

    final logoColors = _getLogoColors(ipo.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isApplied
              ? (isDark ? const Color(0xFF10B981) : forestGreen).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isApplied ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticHelper.light();
            context.push('/ipo/${ipo.id}');
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Name, and Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Styled Logo Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: logoColors['bg'],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          _getLogoIcon(ipo.name),
                          color: logoColors['fg'],
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  ipo.companyName,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(ipo.dynamicStatus),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ipo.priceBandFormatted,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                              ),
                              Text(
                                dateText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Divider Line
                Container(
                  height: 0.8,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),

                const SizedBox(height: 12),

                // 3-Column Metric Row: Min Invest | Lot Size | GMP
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Min. Invest',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatPaise(ipo.minInvestmentRupees * 100, currencyCode: 'INR'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
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
                          Text(
                            'Lot Size',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ipo.lotSize} Shares',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
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
                          Text(
                            'GMP',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (context) {
                              final gmp = ipo.currentGmp;
                              final String gmpText;
                              final Color gmpColor;
                              if (ipo.isGmpExpired) {
                                gmpText = ipo.dynamicStatus == IpoStatus.listed ? '-' : 'Expired';
                                gmpColor = isDark ? Colors.white38 : Colors.black38;
                              } else if (gmp == null) {
                                gmpText = 'N/A';
                                gmpColor = isDark ? Colors.white38 : Colors.black38;
                              } else if (gmp > 0) {
                                gmpText = '+₹$gmp';
                                gmpColor = const Color(0xFF10B981);
                              } else if (gmp < 0) {
                                gmpText = '-₹${gmp.abs()}';
                                gmpColor = const Color(0xFFEF4444);
                              } else {
                                gmpText = '₹0 (Flat)';
                                gmpColor = isDark ? Colors.white70 : const Color(0xFF475569);
                              }
                              return Text(
                                gmpText,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: gmpColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Timeline Dates Row
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      ipo.allotmentDate != null
                          ? 'Allotment: ${DateFormatter.formatShortDate(ipo.allotmentDate!)}'
                          : 'Allotment: Unannounced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white38 : Colors.black26)),
                    const SizedBox(width: 8),
                    Text(
                      ipo.listingDate != null
                          ? 'Listing: ${DateFormatter.formatShortDate(ipo.listingDate!)}'
                          : 'Listing: Unannounced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),

                // Applied Accounts Row (if applied)
                if (isApplied) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildStackedAvatars(applications),
                        const SizedBox(width: 8),
                        Text(
                          'Applied • ${applications.length} account${applications.length != 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF10B981) : darkGreenText,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(IpoStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case IpoStatus.open:
        bg = softGreenBadge;
        fg = darkGreenText;
        label = 'OPEN';
        break;
      case IpoStatus.upcoming:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'UPCOMING';
        break;
      case IpoStatus.closed:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'CLOSED';
        break;
      case IpoStatus.allotmentOut:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'ALLOTMENT OUT';
        break;
      case IpoStatus.listed:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'LISTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildStackedAvatars(List<IpoApplication> apps) {
    return SizedBox(
      width: (apps.length.clamp(1, 3) * 14.0) + 10.0,
      height: 20,
      child: Stack(
        children: List.generate(apps.length.clamp(1, 3), (i) {
          final colors = [
            const Color(0xFF10B981),
            const Color(0xFF3B82F6),
            const Color(0xFF8B5CF6),
          ];
          final char = apps[i].accountName.isNotEmpty ? apps[i].accountName[0].toUpperCase() : 'M';
          return Positioned(
            left: i * 12.0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  char,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Map<String, Color> _getLogoColors(String name) {
    final hash = name.hashCode.abs();
    final palettes = [
      {'bg': const Color(0xFFECFDF5), 'fg': const Color(0xFF10B981)}, // Emerald
      {'bg': const Color(0xFFF5F3FF), 'fg': const Color(0xFF8B5CF6)}, // Purple
      {'bg': const Color(0xFFFEF3C7), 'fg': const Color(0xFFF59E0B)}, // Amber
      {'bg': const Color(0xFFEFF6FF), 'fg': const Color(0xFF3B82F6)}, // Blue
      {'bg': const Color(0xFFFFF1F2), 'fg': const Color(0xFFF43F5E)}, // Rose
    ];
    return palettes[hash % palettes.length];
  }

  IconData _getLogoIcon(String name) {
    final hash = name.hashCode.abs() % 4;
    switch (hash) {
      case 0:
        return Icons.layers_rounded;
      case 1:
        return Icons.diamond_outlined;
      case 2:
        return Icons.token_rounded;
      default:
        return Icons.pie_chart_rounded;
    }
  }

  Widget _buildPortfolioSummaryCard(IpoViewModel ipoVm, bool isDark) {
    final blockedPaise = ipoVm.totalBlockedPaise;
    final investedPaise = ipoVm.totalInvestedPaise;
    final refundPaise = ipoVm.totalPendingRefundPaise;
    final activeCount = ipoVm.openCount;
    final upcomingCount = ipoVm.upcomingCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: darkGreenText),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PORTFOLIO OVERVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticHelper.light();
                  context.push('/ipo-history');
                },
                child: Row(
                  children: [
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF10B981) : forestGreen,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF10B981) : forestGreen),
                  ],
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
                      'Blocked Mandates',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.formatPaise(blockedPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invested',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.formatPaise(investedPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF10B981) : darkGreenText,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Refund',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.formatPaise(refundPaise, currencyCode: 'INR'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: refundPaise > 0 ? const Color(0xFFF59E0B) : (isDark ? Colors.white60 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  '$activeCount Active • $upcomingCount Upcoming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(ipoVm.attributionUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ipoVm.sourceAttribution,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.open_in_new_rounded, size: 9, color: Color(0xFF15803D)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, IpoViewModel ipoVm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.candlestick_chart_outlined, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No ${ipoVm.selectedTab.replaceAll('_', ' ')} IPOs available',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ipoVm.isApiConfigured
                  ? 'All IPO records are up to date.'
                  : 'IPO Guru API not configured yet. Fallback cache is active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ipoVm.loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Feed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataAttributionFooter(bool isDark, IpoViewModel ipoVm) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(ipoVm.attributionUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  "Data: IPO Guru",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 11,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
