import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/haptic_feedback_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../../../domain/models/trip.dart';
import '../../../../domain/models/trip_member.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/trip_detail_viewmodel.dart';

class MergeMembersSheet extends StatefulWidget {
  final Trip trip;
  final TripMember? preselectedMemberA;
  final TripMember? preselectedMemberB;

  const MergeMembersSheet({
    super.key,
    required this.trip,
    this.preselectedMemberA,
    this.preselectedMemberB,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Trip trip,
    TripMember? preselectedMemberA,
    TripMember? preselectedMemberB,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MergeMembersSheet(
        trip: trip,
        preselectedMemberA: preselectedMemberA,
        preselectedMemberB: preselectedMemberB,
      ),
    );
  }

  @override
  State<MergeMembersSheet> createState() => _MergeMembersSheetState();
}

class _MergeMembersSheetState extends State<MergeMembersSheet> {
  TripMember? _memberA;
  TripMember? _memberB;
  TripMember? _canonicalMember;
  bool _isExecuting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _memberA = widget.preselectedMemberA;
    _memberB = widget.preselectedMemberB;
    _autoSelectCanonical();
  }

  void _autoSelectCanonical() {
    if (_memberA != null && _memberB != null) {
      // If one is real user and one is unclaimed, prefer real user
      if (!_memberA!.isUnclaimed && _memberB!.isUnclaimed) {
        _canonicalMember = _memberA;
      } else if (_memberA!.isUnclaimed && !_memberB!.isUnclaimed) {
        _canonicalMember = _memberB;
      } else if (_memberA!.isCreator) {
        _canonicalMember = _memberA;
      } else if (_memberB!.isCreator) {
        _canonicalMember = _memberB;
      } else {
        _canonicalMember = _memberA;
      }
    }
  }

  TripMember? get _sourceMember {
    if (_memberA == null || _memberB == null || _canonicalMember == null) return null;
    return _canonicalMember!.id == _memberA!.id ? _memberB : _memberA;
  }

  bool get _isDualRealUserConflict {
    if (_memberA == null || _memberB == null) return false;
    final isAReal = !_memberA!.isUnclaimed && _memberA!.userId.isNotEmpty && !_memberA!.userId.startsWith('unclaimed_');
    final isBReal = !_memberB!.isUnclaimed && _memberB!.userId.isNotEmpty && !_memberB!.userId.startsWith('unclaimed_');
    return isAReal && isBReal && _memberA!.userId != _memberB!.userId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final currentUserId = authVm.currentUser?.id ?? '';

    // Available members (excluding merged tombstones)
    final allMembers = widget.trip.members.where((m) => !m.isMerged).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.merge_type_rounded, color: AppColors.emeraldPrimary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merge Duplicate Members',
                          style: AppTypography.titleMedium(isDark: isDark).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Consolidate duplicate identities into one participant without losing financial records.',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Step 1: Select 2 Members
              Text(
                '1. SELECT PARTICIPANTS TO MERGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 8),

              // Member A Picker
              _buildMemberDropdown(
                label: 'First Participant',
                selected: _memberA,
                exclude: _memberB,
                allMembers: allMembers,
                isDark: isDark,
                onChanged: (m) {
                  setState(() {
                    _memberA = m;
                    _autoSelectCanonical();
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 10),

              // Member B Picker
              _buildMemberDropdown(
                label: 'Second Participant',
                selected: _memberB,
                exclude: _memberA,
                allMembers: allMembers,
                isDark: isDark,
                onChanged: (m) {
                  setState(() {
                    _memberB = m;
                    _autoSelectCanonical();
                    _errorMessage = null;
                  });
                },
              ),

              // Conflict Alert if both are registered Kith accounts
              if (_isDualRealUserConflict) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.roseAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.roseAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.roseAccent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cannot merge two distinct authenticated Kith user accounts. Merging is reserved for unclaimed duplicate profiles.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.roseAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Step 2: Select Surviving (Canonical) Identity
              if (_memberA != null && _memberB != null && !_isDualRealUserConflict) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '2. CHOOSE SURVIVING IDENTITY (KEEP)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildSurvivingOptionCard(
                        member: _memberA!,
                        isChosen: _canonicalMember?.id == _memberA!.id,
                        isDark: isDark,
                        onTap: () {
                          HapticHelper.selection();
                          setState(() => _canonicalMember = _memberA);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSurvivingOptionCard(
                        member: _memberB!,
                        isChosen: _canonicalMember?.id == _memberB!.id,
                        isDark: isDark,
                        onTap: () {
                          HapticHelper.selection();
                          setState(() => _canonicalMember = _memberB);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Step 3: Financial Impact Review
                Text(
                  '3. FINANCIAL IMPACT REVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFinancialReviewCard(isDark, tripDetailVm),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.roseAccent),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Cancel',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: 'Merge Members',
                      variant: AppButtonVariant.primary,
                      isLoading: _isExecuting,
                      icon: Icons.merge_type_rounded,
                      onPressed: (_memberA == null ||
                              _memberB == null ||
                              _canonicalMember == null ||
                              _isDualRealUserConflict ||
                              _isExecuting)
                          ? null
                          : () => _executeMerge(tripDetailVm, currentUserId),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDropdown({
    required String label,
    required TripMember? selected,
    required TripMember? exclude,
    required List<TripMember> allMembers,
    required bool isDark,
    required ValueChanged<TripMember?> onChanged,
  }) {
    final eligible = allMembers.where((m) => m.id != exclude?.id).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TripMember>(
          value: selected,
          hint: Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary),
          dropdownColor: isDark ? const Color(0xFF1A222A) : Colors.white,
          items: eligible.map((m) {
            return DropdownMenuItem<TripMember>(
              value: m,
              child: Row(
                children: [
                  MemberAvatar(name: m.displayName, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.isUnclaimed
                          ? (isDark ? Colors.white10 : Colors.black12)
                          : AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.isUnclaimed ? 'Unclaimed' : (m.isCreator ? 'Creator' : 'Joined'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: m.isUnclaimed
                            ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                            : AppColors.emeraldPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSurvivingOptionCard({
    required TripMember member,
    required bool isChosen,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isChosen
              ? AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF161D24) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChosen ? AppColors.emeraldPrimary : (isDark ? Colors.white10 : Colors.black12),
            width: isChosen ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MemberAvatar(name: member.displayName, size: 28),
                Icon(
                  isChosen ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isChosen ? AppColors.emeraldPrimary : (isDark ? Colors.white30 : Colors.black26),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              member.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              isChosen ? 'SURVIVES' : 'WILL BE MERGED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isChosen ? AppColors.emeraldPrimary : AppColors.amberAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialReviewCard(bool isDark, TripDetailViewModel vm) {
    final expenses = vm.expenses;

    int aPaidPaise = 0;
    int aSharePaise = 0;
    int bPaidPaise = 0;
    int bSharePaise = 0;

    for (final exp in expenses) {
      if (exp.isDeleted) continue;
      if (exp.paidById == _memberA?.id) {
        aPaidPaise += exp.amountInPaise;
      }
      if (exp.paidById == _memberB?.id) {
        bPaidPaise += exp.amountInPaise;
      }
      for (final s in exp.splits) {
        if (s.memberId == _memberA?.id) aSharePaise += s.amountInPaise;
        if (s.memberId == _memberB?.id) bSharePaise += s.amountInPaise;
      }
    }

    final combinedPaid = aPaidPaise + bPaidPaise;
    final combinedShare = aSharePaise + bSharePaise;
    final combinedNet = combinedPaid - combinedShare;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_memberA?.displayName}:',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              Text(
                'Paid: ${CurrencyFormatter.formatPaise(aPaidPaise)} • Share: ${CurrencyFormatter.formatPaise(aSharePaise)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_memberB?.displayName}:',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              Text(
                'Paid: ${CurrencyFormatter.formatPaise(bPaidPaise)} • Share: ${CurrencyFormatter.formatPaise(bSharePaise)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Combined (${_canonicalMember?.displayName}):',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
              ),
              Text(
                'Paid: ${CurrencyFormatter.formatPaise(combinedPaid)} • Net: ${combinedNet >= 0 ? "+" : ""}${CurrencyFormatter.formatPaise(combinedNet)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: combinedNet >= 0 ? AppColors.positiveGreenLight : AppColors.roseAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executeMerge(TripDetailViewModel vm, String currentUserId) async {
    final src = _sourceMember;
    final canon = _canonicalMember;
    if (src == null || canon == null) return;

    setState(() {
      _isExecuting = true;
      _errorMessage = null;
    });

    try {
      await vm.mergeMembers(
        sourceMemberId: src.id,
        canonicalMemberId: canon.id,
        currentUserId: currentUserId,
      );
      HapticHelper.heavy();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully merged "${src.displayName}" into "${canon.displayName}" ✓'),
            backgroundColor: AppColors.positiveGreenLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
        HapticHelper.light();
      }
    }
  }
}
