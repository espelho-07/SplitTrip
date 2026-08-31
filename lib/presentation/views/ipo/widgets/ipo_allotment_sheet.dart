import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../domain/models/ipo/ipo_application.dart';
import '../../../viewmodels/ipo_viewmodel.dart';

class IpoAllotmentSheet extends StatefulWidget {
  final IpoApplication application;

  const IpoAllotmentSheet({
    super.key,
    required this.application,
  });

  static Future<void> show(BuildContext context, IpoApplication application) {
    HapticHelper.light();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IpoAllotmentSheet(application: application),
    );
  }

  @override
  State<IpoAllotmentSheet> createState() => _IpoAllotmentSheetState();
}

class _IpoAllotmentSheetState extends State<IpoAllotmentSheet> {
  late IpoApplicationStatus _selectedStatus;
  late int _allottedLots;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.application.status == IpoApplicationStatus.applied ||
            widget.application.status == IpoApplicationStatus.fundsBlocked
        ? IpoApplicationStatus.allotted
        : widget.application.status;
    _allottedLots = widget.application.allottedLots ?? widget.application.lotsApplied;
    _notesController.text = widget.application.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = widget.application;
    final ipoVm = context.read<IpoViewModel>();

    int calculatedInvestedPaise = 0;
    int calculatedReleasedPaise = app.applicationAmountInPaise;

    if (_selectedStatus == IpoApplicationStatus.allotted) {
      calculatedInvestedPaise = app.lotsApplied * app.lotSize * app.bidPriceInRupees * 100;
      calculatedReleasedPaise = 0;
    } else if (_selectedStatus == IpoApplicationStatus.partiallyAllotted) {
      final calc = IpoApplication.calculateAllotmentAmounts(
        applicationAmountPaise: app.applicationAmountInPaise,
        allottedLots: _allottedLots,
        lotSize: app.lotSize,
        issuePriceRupees: app.bidPriceInRupees,
      );
      calculatedInvestedPaise = calc['investedPaise'] ?? 0;
      calculatedReleasedPaise = calc['releasedPaise'] ?? 0;
    } else {
      // notAllotted
      calculatedInvestedPaise = 0;
      calculatedReleasedPaise = app.applicationAmountInPaise;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
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
              'Record Allotment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${app.ipoName} • ${app.lotsApplied} Lots Applied (${CurrencyFormatter.formatPaise(app.applicationAmountInPaise, currencyCode: 'INR')})',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Allotment Outcome Choice
            _buildOutcomeTile(
              status: IpoApplicationStatus.allotted,
              title: 'Full Allotment',
              subtitle: 'All ${app.lotsApplied} lots allotted (${app.lotsApplied * app.lotSize} shares)',
              icon: Icons.check_circle_outline_rounded,
              color: isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildOutcomeTile(
              status: IpoApplicationStatus.partiallyAllotted,
              title: 'Partial Allotment',
              subtitle: 'A portion of applied lots was allotted',
              icon: Icons.pie_chart_outline_rounded,
              color: Colors.amber,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildOutcomeTile(
              status: IpoApplicationStatus.notAllotted,
              title: 'Not Allotted',
              subtitle: '0 lots allotted • 100% funds released/refunded',
              icon: Icons.cancel_outlined,
              color: isDark ? AppColors.negativeRedDark : AppColors.negativeRedLight,
              isDark: isDark,
            ),

            if (_selectedStatus == IpoApplicationStatus.partiallyAllotted) ...[
              const SizedBox(height: 16),
              Text(
                'Number of Lots Allotted (out of ${app.lotsApplied})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: _allottedLots > 1
                        ? () => setState(() => _allottedLots--)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_allottedLots Lots (${_allottedLots * app.lotSize} Shares)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: _allottedLots < app.lotsApplied
                        ? () => setState(() => _allottedLots++)
                        : null,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            // Financial Impact Summary Box
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
                        Text(
                          'Invested Amount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(calculatedInvestedPaise, currencyCode: 'INR'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Released / Refunded',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(calculatedReleasedPaise, currencyCode: 'INR'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: calculatedReleasedPaise > 0
                                ? (isDark ? AppColors.positiveGreenDark : AppColors.positiveGreenLight)
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  HapticHelper.medium();
                  Navigator.pop(context);
                  await ipoVm.updateAllotment(
                    applicationId: app.id,
                    status: _selectedStatus,
                    allottedLots: _selectedStatus == IpoApplicationStatus.allotted
                        ? app.lotsApplied
                        : (_selectedStatus == IpoApplicationStatus.partiallyAllotted ? _allottedLots : 0),
                    notes: _notesController.text.trim(),
                  );
                },
                child: const Text(
                  'Save Allotment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeTile({
    required IpoApplicationStatus status,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        HapticHelper.selection();
        setState(() => _selectedStatus = status);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF141A21) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
