import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../../../domain/models/ipo/ipo_application.dart';
import '../../viewmodels/ipo_viewmodel.dart';
import 'widgets/ipo_allotment_sheet.dart';

class IpoDetailView extends StatelessWidget {
  final String ipoId;

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
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('IPO not found')),
      );
    }

    final applications = ipoVm.getAllApplicationsForIpo(ipo.id);
    final isApplied = applications.isNotEmpty;

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
          ipo.symbol.isNotEmpty ? ipo.symbol : 'IPO Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              ipo.isTracked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: ipo.isTracked
                  ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            onPressed: () {
              HapticHelper.light();
              ipoVm.toggleTrackIpo(ipo.id);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // 1. Company Header Hero Card
          _buildCompanyHeroCard(context, ipo, isDark),

          const SizedBox(height: 16),

          // 2. Timeline Milestones (Open -> Close -> Allotment -> Listing)
          _buildMilestonesCard(context, ipo, isDark),

          const SizedBox(height: 16),

          // 3. Issue Specifications Grid
          _buildKeySpecsCard(context, ipo, isDark),

          // 4. GMP & Subscription Insights (if available)
          if (ipo.gmp != null || ipo.subscriptionOverall != null) ...[
            const SizedBox(height: 16),
            _buildMarketInsightsCard(context, ipo, isDark),
          ],

          const SizedBox(height: 20),

          // 5. User's Applications & Funding Breakdowns (All Accounts)
          if (isApplied) ...[
            Text(
              '${applications.length} APPLICATION${applications.length > 1 ? 'S' : ''} RECORDED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 10),
            for (final app in applications) ...[
              _buildApplicationSection(context, ipo, app, isDark, ipoVm),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 6),
          ],

          // 6. Context Action Buttons (Add from context, Edit, etc.)
          _buildContextualActions(context, ipo, applications.firstOrNull, isDark),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(isApplied ? Icons.edit_note_rounded : Icons.how_to_reg_rounded, size: 20),
              label: Text(
                isApplied ? 'Edit Application & Funding' : 'I Applied to this IPO',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                HapticHelper.medium();
                context.push('/ipo/${ipo.id}/apply');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyHeroCard(BuildContext context, Ipo ipo, bool isDark) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ipo.marketType.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ipo.symbol,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ipo.isBiddingActive
                      ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ipo.dynamicStatus.displayName,
                  style: TextStyle(
                    fontSize: 11,
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
          Text(
            ipo.name,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ipo.companyName,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard(BuildContext context, Ipo ipo, bool isDark) {
    return Container(
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
          Text(
            'KEY DATES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateColumn('Opens', ipo.openDate, isDark),
              _buildDateDivider(isDark),
              _buildDateColumn('Closes', ipo.closeDate, isDark),
              _buildDateDivider(isDark),
              _buildDateColumn('Allotment', ipo.allotmentDate, isDark),
              _buildDateDivider(isDark),
              _buildDateColumn('Listing', ipo.listingDate, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateColumn(String label, DateTime? date, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date != null ? DateFormatter.formatDate(date) : 'TBD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildDateDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
    );
  }

  Widget _buildKeySpecsCard(BuildContext context, Ipo ipo, bool isDark) {
    return Container(
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
          Text(
            'ISSUE SPECIFICATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSpecItem(
                  label: 'Price Band',
                  value: ipo.priceBandFormatted,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _buildSpecItem(
                  label: 'Lot Size',
                  value: '${ipo.lotSize} Shares',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSpecItem(
                  label: 'Min. Investment',
                  value: '₹${CurrencyFormatter.formatPaise(ipo.minInvestmentRupees * 100, currencyCode: 'INR')}',
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _buildSpecItem(
                  label: 'Issue Size',
                  value: ipo.issueSizeCrores != null ? '₹${ipo.issueSizeCrores} Cr' : 'TBD',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem({required String label, required String value, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketInsightsCard(BuildContext context, Ipo ipo, bool isDark) {
    final sub = ipo.subscription;
    final hasSubCategories = sub != null && sub.hasAnyData;
    final maxP = ipo.maxPrice > 0 ? ipo.maxPrice : (ipo.minPrice > 0 ? ipo.minPrice : 1);
    final estGainPct = ipo.gmp != null && maxP > 0 ? ((ipo.gmp! / maxP) * 100).toStringAsFixed(1) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MARKET INSIGHTS & SUBSCRIPTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              Text(
                'Unofficial / Indicative',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (ipo.gmp != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GMP (Grey Market)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${ipo.gmp}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                            ),
                          ),
                          if (estGainPct != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+$estGainPct%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (ipo.subscriptionOverall != null || sub?.total != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Subscription',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ipo.subscriptionOverall ?? sub?.total}x',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Detailed category breakdown if available
          if (hasSubCategories) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'CATEGORY-WISE SUBSCRIPTION',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (sub.qib != null) _buildSubscriptionChip('QIB (Institutions)', '${sub.qib}x', isDark),
                if (sub.nii != null) _buildSubscriptionChip('NII / HNI', '${sub.nii}x', isDark),
                if (sub.retail != null) _buildSubscriptionChip('Retail (RII)', '${sub.retail}x', isDark),
                if (sub.employee != null) _buildSubscriptionChip('Employee', '${sub.employee}x', isDark),
                if (sub.shareholder != null) _buildSubscriptionChip('Shareholder', '${sub.shareholder}x', isDark),
              ],
            ),
          ],

          if (ipo.gmp != null) ...[
            const SizedBox(height: 10),
            Text(
              '* GMP (Grey Market Premium) is unofficial indicative pricing from dealers for informational purposes only.',
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.7) : AppColors.lightTextMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationSection(
    BuildContext context,
    Ipo ipo,
    IpoApplication app,
    bool isDark,
    IpoViewModel ipoVm,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.4),
          width: 1.2,
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
                  Icon(Icons.verified_rounded, size: 18, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
                  const SizedBox(width: 6),
                  Text(
                    app.accountName.toLowerCase() == 'me' ? 'MY APPLICATION' : '${app.accountName.toUpperCase()} APPLICATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  app.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Applied',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Lots & Shares',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  Text(
                    '${app.lotsApplied} Lots (${app.lotsApplied * app.lotSize} Shares)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Funding Breakdown (Who funded this IPO)
          Text(
            'WHO FUNDED THIS APPLICATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),

          ...app.fundings.map((funding) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (!funding.isSelf && funding.personName != null) {
                      HapticHelper.light();
                      context.push('/person/${Uri.encodeComponent(funding.personName!)}');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        MemberAvatar(name: funding.displayName, size: 28, showBorder: false),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                funding.displayName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                funding.isSelf ? 'Self Funded' : 'Peer Contribution (Linked to Person Chat)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(funding.amountInPaise, currencyCode: 'INR'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        if (!funding.isSelf) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Payment Breakdown (Paid vs Remaining)
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Already Paid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatPaise(app.effectivePaidPaise, currencyCode: 'INR'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remaining Due', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: app.effectiveRemainingPaise > 0
                              ? (isDark ? Colors.amberAccent : Colors.amber.shade800)
                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons: Allotment, Mark Received & WhatsApp Request
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => IpoAllotmentSheet.show(context, app),
                  icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                  label: const Text('Update Allotment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              if (app.effectiveRemainingPaise > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _markIpoPaymentReceived(context, app, ipoVm),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Mark Received', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),

          if (app.effectiveRemainingPaise > 0 && !app.accountName.toLowerCase().startsWith('me')) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366), width: 1),
                ),
                onPressed: () => _sendWhatsAppIpoPaymentRequest(context, app, ipo),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text(
                  'Request ${CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR')} via WhatsApp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          if (app.status == IpoApplicationStatus.allotted ||
              app.status == IpoApplicationStatus.partiallyAllotted ||
              app.status == IpoApplicationStatus.notAllotted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invested', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(
                          CurrencyFormatter.formatPaise(app.actualInvestedAmountInPaise ?? 0, currencyCode: 'INR'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Released / Refunded', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(
                          CurrencyFormatter.formatPaise(app.releasedAmountInPaise ?? 0, currencyCode: 'INR'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markIpoPaymentReceived(BuildContext context, IpoApplication app, IpoViewModel ipoVm) async {
    HapticHelper.medium();
    final remaining = app.effectiveRemainingPaise;
    if (remaining <= 0) return;

    await ipoVm.recordPayment(
      applicationId: app.id,
      amountInPaise: remaining,
      note: 'Payment received for ${app.ipoName} (${app.accountName})',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${CurrencyFormatter.formatPaise(remaining, currencyCode: 'INR')} received for ${app.accountName}!'),
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
    }
  }

  Future<void> _sendWhatsAppIpoPaymentRequest(BuildContext context, IpoApplication app, Ipo ipo) async {
    HapticHelper.medium();
    final totalFormatted = CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR');
    final paidFormatted = CurrencyFormatter.formatPaise(app.effectivePaidPaise, currencyCode: 'INR');
    final remainingFormatted = CurrencyFormatter.formatPaise(app.effectiveRemainingPaise, currencyCode: 'INR');

    final message = '''*Kith — IPO Payment Request*
*IPO:* ${ipo.name}
*Account:* ${app.accountName}
*Application Amount:* $totalFormatted
*Already Paid:* $paidFormatted
*Remaining:* $remainingFormatted
*Application Status:* ${app.status.displayName}

Please send the remaining $remainingFormatted.
— Sent via Kith''';

    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    final webWaUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      } else if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment request copied to clipboard! Paste in WhatsApp or SMS.'),
          backgroundColor: AppColors.emeraldPrimary,
        ),
      );
    }
  }

  Widget _buildContextualActions(
    BuildContext context,
    Ipo ipo,
    IpoApplication? application,
    bool isDark,
  ) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent, size: 18),
          ),
          title: const Text('Add from Context', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text(
            'Create an expense or debt record linked to ${ipo.name}',
            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: () {
            HapticHelper.light();
            final amt = application?.applicationAmountInPaise;
            context.push(
              '/add-expense?title=${Uri.encodeComponent(ipo.name)}${amt != null ? '&amount=$amt' : ''}',
            );
          },
        ),
      ],
    );
  }
}
