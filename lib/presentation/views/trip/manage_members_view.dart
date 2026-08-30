import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_member.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/trip_detail_viewmodel.dart';
import 'widgets/merge_members_sheet.dart';

class ManageMembersView extends StatefulWidget {
  final String tripId;

  const ManageMembersView({super.key, required this.tripId});

  static Route<void> route(String tripId) {
    return MaterialPageRoute(
      builder: (_) => ManageMembersView(tripId: tripId),
    );
  }

  @override
  State<ManageMembersView> createState() => _ManageMembersViewState();
}

class _ManageMembersViewState extends State<ManageMembersView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripDetailVm = context.watch<TripDetailViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final trip = tripDetailVm.trip ?? context.watch<TripRepository>().getCachedTripById(widget.tripId);
    final currentUserId = authVm.currentUser?.id ?? '';

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final isCreator = trip.creatorId == currentUserId ||
        trip.members.any((m) => m.userId == currentUserId && m.isCreator);

    final activeMembers = trip.members.where((m) => !m.isUnclaimed && !m.isMerged).toList();
    final unclaimedMembers = trip.members.where((m) => m.isUnclaimed && !m.isMerged).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Members', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.emeraldPrimary),
            tooltip: 'Add Member',
            onPressed: isCreator ? () => _showAddMemberDialog(context, tripDetailVm, currentUserId) : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Admin Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF101B1E), const Color(0xFF0F1418)]
                    : [const Color(0xFFE6F4EA), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.emeraldPrimary.withValues(alpha: 0.3) : AppColors.emeraldPrimary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.emeraldPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCreator ? 'Trip Admin Access' : 'Participant View',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCreator
                            ? 'You have administrative authority to manage members, rename unclaimed participants, and merge duplicates.'
                            : 'Only the trip creator can manage, rename, or merge participants.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Primary Admin Actions
          if (isCreator) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Add Member',
                    icon: Icons.person_add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () => _showAddMemberDialog(context, tripDetailVm, currentUserId),
                  ),
                ),
                if (trip.members.where((m) => !m.isMerged).length >= 2) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: 'Merge Members',
                      icon: Icons.merge_type_rounded,
                      variant: AppButtonVariant.outline,
                      onPressed: () => MergeMembersSheet.show(context, trip: trip),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Section 1: Active / Claimed Members
          _buildSectionHeader('ACTIVE MEMBERS (${activeMembers.length})', isDark),
          const SizedBox(height: 8),
          if (activeMembers.isEmpty)
            _buildEmptyState('No active accounts joined yet.', isDark)
          else
            for (final member in activeMembers)
              _buildMemberCard(
                member: member,
                isCreatorUser: isCreator,
                isDark: isDark,
                currentUserId: currentUserId,
                trip: trip,
                tripDetailVm: tripDetailVm,
              ),

          const SizedBox(height: AppSpacing.xl),

          // Section 2: Invited / Unclaimed Members
          _buildSectionHeader('INVITED / UNCLAIMED MEMBERS (${unclaimedMembers.length})', isDark),
          const SizedBox(height: 8),
          if (unclaimedMembers.isEmpty)
            _buildEmptyState('No unclaimed members in this trip.', isDark)
          else
            for (final member in unclaimedMembers)
              _buildMemberCard(
                member: member,
                isCreatorUser: isCreator,
                isDark: isDark,
                currentUserId: currentUserId,
                trip: trip,
                tripDetailVm: tripDetailVm,
              ),

          const SizedBox(height: AppSpacing.xl),

          // Share Invite Code Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D24) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite via Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Trip Code: ${trip.inviteCode}',
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
                  onPressed: () {
                    HapticHelper.light();
                    Clipboard.setData(ClipboardData(text: trip.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Trip code ${trip.inviteCode} copied! ✓')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      ),
    );
  }

  Widget _buildEmptyState(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard({
    required TripMember member,
    required bool isCreatorUser,
    required bool isDark,
    required String currentUserId,
    required Trip trip,
    required TripDetailViewModel tripDetailVm,
  }) {
    final isSelf = member.userId == currentUserId || member.id == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MemberAvatar(name: member.displayName, avatarUrl: member.avatarUrl, size: 40),
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
                            child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.isUnclaimed
                          ? 'Unclaimed participant'
                          : (member.isCreator ? 'Trip Creator' : 'Joined with Kith account'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (member.isCreator)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Creator',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary),
                  ),
                )
              else if (member.isUnclaimed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Unclaimed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
            ],
          ),

          // Admin Actions for this specific member
          if (isCreatorUser && !member.isCreator) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (member.isUnclaimed) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.emeraldPrimary),
                    label: const Text('Rename', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emeraldPrimary)),
                    onPressed: () => _showRenameDialog(context, member, tripDetailVm, currentUserId),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.merge_type_rounded, size: 14, color: AppColors.indigoAccent),
                  label: const Text('Merge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.indigoAccent)),
                  onPressed: () => MergeMembersSheet.show(context, trip: trip, preselectedMemberA: member),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.person_remove_outlined, size: 14, color: AppColors.roseAccent),
                  label: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.roseAccent)),
                  onPressed: () => _showRemoveConfirmation(context, member, trip, tripDetailVm, currentUserId),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext parentContext, TripDetailViewModel vm, String currentUserId) {
    final controller = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Trip Member', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your friend\'s name to add them to this trip and split expenses.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Rahul',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: 'Add',
            height: 40.0,
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(parentContext);
              try {
                await vm.addMember(name, currentUserId);
                HapticHelper.heavy();
                messenger.showSnackBar(
                  SnackBar(content: Text('Added "$name" to trip ✓')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())),
                );
              }
            },

          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext parentContext, TripMember member, TripDetailViewModel vm, String currentUserId) {
    final controller = TextEditingController(text: member.displayName);
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Participant', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change the display name for unclaimed member "${member.displayName}".',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: 'Save',
            height: 40.0,
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == member.displayName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(parentContext);
              try {
                await vm.renameMember(member.id, newName, currentUserId);
                HapticHelper.heavy();
                messenger.showSnackBar(
                  SnackBar(content: Text('Renamed to "$newName" ✓')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(
    BuildContext parentContext,
    TripMember member,
    Trip trip,
    TripDetailViewModel vm,
    String currentUserId,
  ) {
    // Check if member has financial records
    final expenses = vm.expenses;
    final hasExpenses = expenses.any((e) =>
        !e.isDeleted &&
        (e.paidById == member.id ||
            e.splits.any((s) => s.memberId == member.id && s.amountInPaise > 0)));

    final settlements = vm.tripRepo.storage.getSavedTripSettlements(trip.id);
    final hasSettlements = settlements.any((s) =>
        s['fromMemberId'] == member.id || s['toMemberId'] == member.id);

    if (hasExpenses || hasSettlements) {
      // Show Financial Safety Warning dialog
      showDialog(
        context: parentContext,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.amberAccent),
              SizedBox(width: 8),
              Text('Financial Protection', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            'Cannot remove "${member.displayName}" because they are involved in active expenses or settlements.\n\nTo remove this participant safely, either settle all balances or use "Merge Members" to combine them with another participant.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
            AppButton(
              text: 'Merge Instead',
              height: 40.0,
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.pop(ctx);
                MergeMembersSheet.show(parentContext, trip: trip, preselectedMemberA: member);
              },
            ),
          ],
        ),
      );
      return;
    }

    // Clean member confirmation dialog
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${member.displayName}"?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This participant has zero financial activity and will be removed from the trip participant list.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: 'Remove',
            height: 40.0,
            variant: AppButtonVariant.danger,
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(parentContext);
              try {
                await vm.removeMember(member.id, currentUserId);
                HapticHelper.heavy();
                messenger.showSnackBar(
                  SnackBar(content: Text('Removed "${member.displayName}" from trip ✓')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())),
                );
              }
            },
          ),
        ],
      ),
    );
  }

}
