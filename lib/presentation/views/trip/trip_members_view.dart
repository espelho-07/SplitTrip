import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../data/repositories/trip_repository.dart';

class TripMembersView extends StatelessWidget {
  final String tripId;

  const TripMembersView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripRepo = context.watch<TripRepository>();
    final trip = tripRepo.getCachedTripById(tripId);

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Trip not found')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C0E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Members', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticHelper.light();
              Clipboard.setData(ClipboardData(text: trip.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Trip code ${trip.inviteCode} copied! ✓')),
              );
            },
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Member List
          for (final member in trip.members)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1418) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  MemberAvatar(name: member.displayName, avatarUrl: member.avatarUrl, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '@${member.displayName.toLowerCase().replaceAll(' ', '')}',
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
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Creator',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6)),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Invite via Link Box (Screen 17)
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
                        'Invite via link',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Anyone with this link or code (${trip.inviteCode}) can join',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Color(0xFF14B8A6)),
                  onPressed: () {
                    HapticHelper.light();
                    Clipboard.setData(ClipboardData(text: 'https://kith.app/join/${trip.inviteCode}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied to clipboard! ✓')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
