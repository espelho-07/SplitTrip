import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Complete participant experience view with distinct categorization:
/// - All Participants
/// - KITH Members (Verified, claimed, sync-eligible accounts)
/// - Virtual Participants (Offline placeholders, creator-managed, claimable)
class TripMembersView extends StatefulWidget {
  final String tripId;

  const TripMembersView({super.key, required this.tripId});

  static Route<void> route(String tripId) {
    return MaterialPageRoute(
      builder: (_) => TripMembersView(tripId: tripId),
    );
  }

  @override
  State<TripMembersView> createState() => _TripMembersViewState();
}

class _TripMembersViewState extends State<TripMembersView> {
  int _selectedTabIndex = 0; // 0: All, 1: KITH Members, 2: Virtual Participants

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripRepo = context.watch<TripRepository>();
    final trip = tripRepo.getCachedTripById(widget.tripId);
    final authVm = context.watch<AuthViewModel>();
    final currentUserId = authVm.currentUser?.id ?? '';

    if (trip == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF14B8A6),
          ),
        ),
      );
    }

    final isCreator = trip.creatorId == currentUserId ||
        trip.members.any((m) => m.userId == currentUserId && m.isCreator);

    final allMembers = trip.members.where((m) => !m.isMerged).toList();
    final kithMembers = allMembers.where((m) => !m.isVirtual).toList();
    final virtualMembers = allMembers.where((m) => m.isVirtual).toList();

    final List<TripMember> displayedMembers;
    switch (_selectedTabIndex) {
      case 1:
        displayedMembers = kithMembers;
        break;
      case 2:
        displayedMembers = virtualMembers;
        break;
      case 0:
      default:
        displayedMembers = allMembers;
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Trip Participants',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Manage & Merge Members',
              onPressed: () {
                HapticHelper.light();
                context.push('/trip/${trip.id}/members/manage');
              },
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.emeraldPrimary),
            tooltip: 'Share Invite Code',
            onPressed: () => _copyInviteCode(trip.inviteCode),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // 1. Top Summary Banner Card
          _buildSummaryHeader(
            trip: trip,
            isDark: isDark,
            allCount: allMembers.length,
            kithCount: kithMembers.length,
            virtualCount: virtualMembers.length,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 2. Segmented Category Filter Pills
          _buildSegmentedFilter(
            isDark: isDark,
            allCount: allMembers.length,
            kithCount: kithMembers.length,
            virtualCount: virtualMembers.length,
          ),

          const SizedBox(height: AppSpacing.md),

          // 3. Member List or Empty State
          if (displayedMembers.isEmpty)
            _buildEmptyState(isDark)
          else
            for (final member in displayedMembers)
              _buildParticipantCard(
                member: member,
                trip: trip,
                isDark: isDark,
                currentUserId: currentUserId,
                isCreatorUser: isCreator,
              ),

          const SizedBox(height: AppSpacing.xl),

          // 4. Invite & Claim Guidance Box
          _buildInviteGuidanceBox(trip: trip, isDark: isDark),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Top summary card with breakdown chips
  Widget _buildSummaryHeader({
    required Trip trip,
    required bool isDark,
    required int allCount,
    required int kithCount,
    required int virtualCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.emeraldPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$allCount Participants • $kithCount KITH, $virtualCount Virtual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Metrics row: KITH Members & Virtual Participants
          Row(
            children: [
              // KITH Members Chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.emeraldPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$kithCount KITH',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                            Text(
                              'Verified & Synced',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Virtual Participants Chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.amber.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$virtualCount Virtual',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade700,
                              ),
                            ),
                            Text(
                              'Virtual • Managed locally',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Guidance explanation
          Text(
            'KITH Members sync expenses across devices in real time. Virtual participants are offline placeholders and can be claimed when your friends join using the trip invite code.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented filter bar
  Widget _buildSegmentedFilter({
    required bool isDark,
    required int allCount,
    required int kithCount,
    required int virtualCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildFilterPill(
            title: 'All ($allCount)',
            index: 0,
            isDark: isDark,
          ),
          _buildFilterPill(
            title: 'KITH ($kithCount)',
            index: 1,
            isDark: isDark,
          ),
          _buildFilterPill(
            title: 'Virtual ($virtualCount)',
            index: 2,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticHelper.selection();
          setState(() => _selectedTabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.emeraldPrimary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Individual participant card
  Widget _buildParticipantCard({
    required TripMember member,
    required Trip trip,
    required bool isDark,
    required String currentUserId,
    required bool isCreatorUser,
  }) {
    final isSelf = member.userId == currentUserId || member.id == currentUserId;
    final isVirtual = member.isVirtual;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVirtual
              ? (isDark ? Colors.amber.withValues(alpha: 0.25) : Colors.amber.withValues(alpha: 0.35))
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MemberAvatar(
                name: member.displayName,
                avatarUrl: member.avatarUrl,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.black12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVirtual
                          ? 'Virtual participant • Managed locally'
                          : '@${member.displayName.toLowerCase().replaceAll(' ', '')} • Active KITH Account',
                      style: TextStyle(
                        fontSize: 12,
                        color: isVirtual
                            ? Colors.amber.shade700
                            : (isDark ? AppColors.darkTextMuted : const Color(0xFF64748B)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Badges
              if (member.isCreator)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Creator',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                )
              else if (!isVirtual)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppColors.emeraldPrimary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'KITH Member',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 12,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Virtual',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // For virtual participants: Provide a 1-tap "Share Invite" action chip
          if (isVirtual) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unclaimed profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticHelper.light();
                    final claimLink = (member.claimToken != null && member.claimToken!.isNotEmpty)
                        ? AppConfig.buildClaimLink(
                            trip.inviteCode,
                            memberId: member.id,
                            claimToken: member.claimToken!,
                            p2pTripSecret: trip.p2pTripSecret,
                          )
                        : trip.inviteCode;
                    Clipboard.setData(ClipboardData(text: claimLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Claim link for ${member.displayName} copied! Share with them to claim. ✓',
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Share Invite Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Empty state for empty tabs
  Widget _buildEmptyState(bool isDark) {
    final String message;
    if (_selectedTabIndex == 1) {
      message = 'No active KITH accounts found.';
    } else if (_selectedTabIndex == 2) {
      message = 'No virtual participants in this trip.\nAll participants have joined with active KITH accounts!';
    } else {
      message = 'No participants found.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              _selectedTabIndex == 2 ? Icons.check_circle_outline_rounded : Icons.people_outline_rounded,
              size: 36,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom invite guidance card
  Widget _buildInviteGuidanceBox({required Trip trip, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite Friends to Join',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share trip code: ${trip.inviteCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.emeraldPrimary),
                tooltip: 'Copy Code',
                onPressed: () => _copyInviteCode(trip.inviteCode),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.emeraldPrimary),
                tooltip: 'Share Invite Link',
                onPressed: () => _copyInviteLink(trip.inviteCode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'When a friend enters this code, they can choose to claim any unclaimed virtual participant to keep all past expenses and splits intact.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _copyInviteCode(String code) {
    HapticHelper.light();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip code $code copied to clipboard! ✓')),
    );
  }

  void _copyInviteLink(String code) {
    HapticHelper.light();
    Clipboard.setData(ClipboardData(text: 'https://kith.app/join/$code'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied to clipboard! ✓')),
    );
  }
}
