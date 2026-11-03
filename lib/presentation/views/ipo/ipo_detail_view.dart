import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';
import 'widgets/ipo_allotment_sheet.dart';

class IpoDetailView extends StatelessWidget {
  final String ipoId;

  static const Color forestGreen = Color(0xFF0E3E28);
  static const Color softGreenBadge = Color(0xFFDCFCE7);
  static const Color darkGreenText = Color(0xFF15803D);

  const IpoDetailView({
    super.key,
    required this.ipoId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ipoVm = context.watch<IpoViewModel>();
    final ipo = ipoVm.getIpoById(ipoId);

    if (ipo == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('IPO not found')),
      );
    }

    final applications = ipoVm.getAllApplicationsForIpo(ipo.id);
    final isApplied = applications.isNotEmpty;

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
          ipo.companyName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              ipo.isTracked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: ipo.isTracked ? (isDark ? const Color(0xFF10B981) : forestGreen) : (isDark ? Colors.white60 : Colors.black54),
            ),
            onPressed: () {
              HapticHelper.light();
              ipoVm.toggleTrackIpo(ipo.id);
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDark ? Colors.white60 : Colors.black54),
            onPressed: () async {
              HapticHelper.light();
              await Clipboard.setData(ClipboardData(text: 'Check out ${ipo.companyName} (${ipo.symbol}) IPO on Kith! Price: ${ipo.priceBandFormatted}, Lot: ${ipo.lotSize} shares.'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('IPO details copied to clipboard!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              // 1. Tags Row: [ Mainboard ] [ Symbol ] [ OPEN NOW ]
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ipo.marketType.displayName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  if (ipo.symbol.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ipo.symbol,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildStatusBadge(ipo.dynamicStatus),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Main Title & Subtitle: "ESDS Software Solution" + "Closes in X days • Closes DD MMM YYYY"
              Text(
                ipo.companyName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              _buildClosingSubtitle(ipo, isDark),

              const SizedBox(height: 18),

              // 3. 2x2 Metric Grid Card (Price Band, Lot Size, Min Invest, Issue Size)
              _buildKeyMetricsGrid(ipo, isDark),

              // 3.5 Prominent GMP & Estimated Listing Profit Card (With Regulatory Disclaimer)
              const SizedBox(height: 14),
              _buildGmpInsightCard(ipo, isDark),

              const SizedBox(height: 18),

              // 4. Timeline Milestones (Opens -> Closes -> Allotment -> Listing)
              _buildTimelineRoadmap(ipo, isDark),

              const SizedBox(height: 22),

              // 5. "My Applications (N)" Section
              if (isApplied) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Applications (${applications.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/ipo-accounts'),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF10B981) : forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final app in applications) ...[
                  _buildApplicationCard(context, ipo, app, ipoVm, isDark),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),

          // 6. Sticky Bottom Action Bar: [ I Applied ] & [ Track Allotment ]
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticHelper.medium();
                          context.push('/ipo/${ipo.id}/apply');
                        },
                        icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                        label: Text(
                          isApplied ? 'Edit Application Plan' : 'Plan Applications',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticHelper.light();
                          _showAllotmentTracker(context, ipo, applications, ipoVm, isDark);
                        },
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text(
                          'Track Allotment',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF10B981) : forestGreen,
                          side: BorderSide(color: isDark ? const Color(0xFF10B981) : forestGreen, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingSubtitle(Ipo ipo, bool isDark) {
    final now = DateTime.now();
    final diffDays = ipo.closeDate.difference(now).inDays;

    String countdown = '';
    if (ipo.dynamicStatus == IpoStatus.open) {
      if (diffDays <= 0) {
        countdown = 'Closes today';
      } else if (diffDays == 1) {
        countdown = 'Closes in 1 day';
      } else {
        countdown = 'Closes in $diffDays days';
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (countdown.isNotEmpty) ...[
            TextSpan(
              text: '$countdown • ',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          TextSpan(text: 'Closes ${DateFormatter.formatDate(ipo.closeDate)}'),
        ],
      ),
    );
  }

  Widget _buildGmpInsightCard(Ipo ipo, bool isDark) {
    final isListed = ipo.status == IpoStatus.listed || ipo.dynamicStatus == IpoStatus.listed;
    final isExpired = ipo.isGmpExpired;
    final currentGmp = ipo.currentGmp;
    final hasValidGmp = currentGmp != null && !isListed;
    final gmp = currentGmp ?? 0;
    final maxPrice = ipo.maxPrice;
    final estListingPrice = ipo.estimatedListingPrice ?? (maxPrice + gmp);
    final gmpPercent = ipo.estimatedGainPercentage != null
        ? ipo.estimatedGainPercentage!.toStringAsFixed(1)
        : (maxPrice > 0 ? ((gmp / maxPrice) * 100).toStringAsFixed(1) : '0.0');
    final estProfitPerLot = gmp * ipo.lotSize;

    final String badgeText;
    final Color badgeBg;
    final Color badgeFg;

    if (isListed) {
      badgeText = 'Listed';
      badgeBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      badgeFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    } else if (isExpired) {
      badgeText = 'Expired (>24h)';
      badgeBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      badgeFg = isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
    } else if (!hasValidGmp) {
      badgeText = 'Not Available';
      badgeBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      badgeFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    } else if (gmp > 0) {
      badgeText = '+$gmpPercent%';
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (gmp < 0) {
      badgeText = '$gmpPercent%';
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFB91C1C);
    } else {
      badgeText = '0.0% (Flat)';
      badgeBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      badgeFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasValidGmp
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasValidGmp
                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.05)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
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
                  Text(hasValidGmp && gmp > 0 ? '🔥' : '📊', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'Grey Market Premium (GMP)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasValidGmp)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GMP Value',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹$gmp',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Est. Listing Price',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹$estListingPrice',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profit / Lot',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${CurrencyFormatter.formatPaise(estProfitPerLot * 100, currencyCode: 'INR')}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                isListed
                    ? 'This issue has listed on stock exchanges. Unofficial pre-listing quotes are no longer active.'
                    : (isExpired
                        ? 'GMP quote has expired. No fresh market indications published in the last 24 hours.'
                        : 'No unofficial grey market premium quotes published for this issue yet.'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'GMP is an unofficial market indication, not a guaranteed listing price or return.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse("https://ipoguru.in");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Data: IPO Guru",
                      style: TextStyle(
                        fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid(Ipo ipo, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCell('Price Band', ipo.priceBandFormatted, isDark)),
              Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              Expanded(child: _buildMetricCell('Lot Size', '${ipo.lotSize} Shares', isDark, leftPadding: 16)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 0.8, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          ),
          Row(
            children: [
              Expanded(
                child: _buildMetricCell(
                  'Min. Investment',
                  CurrencyFormatter.formatPaise(ipo.minInvestmentRupees * 100, currencyCode: 'INR'),
                  isDark,
                ),
              ),
              Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildMetricCell(
                  'Issue Size',
                  ipo.issueSizeCrores != null && ipo.issueSizeCrores! > 0 ? '₹${ipo.issueSizeCrores!.toStringAsFixed(0)} Cr' : 'TBD',
                  isDark,
                  leftPadding: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, bool isDark, {double leftPadding = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRoadmap(Ipo ipo, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimelineStep('Opens', ipo.openDate, Icons.check_circle_outline_rounded, const Color(0xFF10B981), isDark),
          _buildTimelineStep('Closes', ipo.closeDate, Icons.calendar_today_outlined, const Color(0xFF3B82F6), isDark),
          _buildTimelineStep('Allotment', ipo.allotmentDate ?? ipo.closeDate.add(const Duration(days: 1)), Icons.pie_chart_outline_rounded, const Color(0xFF8B5CF6), isDark),
          _buildTimelineStep('Listing', ipo.listingDate ?? ipo.closeDate.add(const Duration(days: 3)), Icons.rocket_launch_outlined, const Color(0xFFF59E0B), isDark),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, DateTime date, IconData icon, Color accent, bool isDark) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: accent, size: 18),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormatter.formatShortDate(date),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    Ipo ipo,
    IpoApplication app,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    final statusBg = _getAllotmentBadgeBg(app.status);
    final statusFg = _getAllotmentBadgeFg(app.status);
    final appAmt = CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR');
    final dateStr = DateFormatter.formatShortDate(app.applicationDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    app.accountName.isNotEmpty ? app.accountName[0].toUpperCase() : 'M',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: darkGreenText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.accountName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.lotsApplied} Lot (${app.totalSharesApplied} Shares)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  app.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(height: 0.8, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Bottom Applied Details & Check Now
          Row(
            children: [
              Text(
                'Applied $appAmt • $dateStr',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (app.status == IpoApplicationStatus.applied || app.status == IpoApplicationStatus.fundsBlocked) ...[
                GestureDetector(
                  onTap: () async {
                    HapticHelper.medium();
                    await ipoVm.checkAllotmentNow(app.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(app.status == IpoApplicationStatus.allotted
                              ? '🎉 Allotment confirmed!'
                              : (app.status == IpoApplicationStatus.notAllotted
                                  ? 'Result: Not Allotted (Funds Released)'
                                  : 'Checked: Allotment awaiting registrar announcement')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Check Now',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ],
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
        label = 'OPEN NOW';
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  Color _getAllotmentBadgeBg(IpoApplicationStatus status) {
    switch (status) {
      case IpoApplicationStatus.allotted:
        return const Color(0xFFDCFCE7);
      case IpoApplicationStatus.notAllotted:
      case IpoApplicationStatus.refunded:
        return const Color(0xFFF3E8FF);
      case IpoApplicationStatus.partiallyAllotted:
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _getAllotmentBadgeFg(IpoApplicationStatus status) {
    switch (status) {
      case IpoApplicationStatus.allotted:
        return darkGreenText;
      case IpoApplicationStatus.notAllotted:
      case IpoApplicationStatus.refunded:
        return const Color(0xFF7E22CE);
      case IpoApplicationStatus.partiallyAllotted:
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF2563EB);
    }
  }

  void _showAllotmentTracker(
    BuildContext context,
    Ipo ipo,
    List<IpoApplication> applications,
    IpoViewModel ipoVm,
    bool isDark,
  ) {
    if (applications.isNotEmpty) {
      IpoAllotmentSheet.show(context, applications.first);
    } else {
      context.push('/ipo/${ipo.id}/apply');
    }
  }
}
