import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/create_trip_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';

class CreateTripView extends StatefulWidget {
  const CreateTripView({super.key});

  @override
  State<CreateTripView> createState() => _CreateTripViewState();
}

class _CreateTripViewState extends State<CreateTripView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();

  static const List<String> _emojis = ['✈️', '🏖️', '🏔️', '🍕', '🚗', '🌴', '🏕️', '🎿', '🎉', '🏠', '☕', '🛳️'];

  @override
  void dispose() {
    _nameController.dispose();
    _friendController.dispose();
    super.dispose();
  }

  void _addFriend() {
    final text = _friendController.text.trim();
    if (text.isNotEmpty) {
      context.read<CreateTripViewModel>().addFriendName(text);
      _friendController.clear();
      HapticHelper.light();
    }
  }

  Future<void> _handleCreate() async {
    final createVm = context.read<CreateTripViewModel>();
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();

    final user = authVm.currentUser;
    if (user == null) return;

    final trip = await createVm.createTrip(user);
    if (trip != null && mounted) {
      await homeVm.loadTrips(user.id);
      if (mounted) {
        context.go('/trip/${trip.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createVm = context.watch<CreateTripViewModel>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Create a Trip'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip Preview Banner
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.getGradient(createVm.coverGradientIndex),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.xlBorder,
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(createVm.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        createVm.name.isEmpty ? 'Trip Name' : createVm.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Trip Name Input
              Text(
                'Trip Name',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Goa Escape, Weekend Camping',
                  prefixIcon: Icon(Icons.flight_takeoff_rounded, size: 20),
                ),
                onChanged: createVm.setName,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Emoji Picker
              Text(
                'Choose Icon',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final em = _emojis[index];
                    final isSelected = createVm.emoji == em;
                    return GestureDetector(
                      onTap: () {
                        HapticHelper.selection();
                        createVm.setEmoji(em);
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary).withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                          borderRadius: AppRadius.mdBorder,
                          border: isSelected
                              ? Border.all(
                                  color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                                  width: 2,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(em, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Gradient Theme Picker
              Text(
                'Cover Gradient Theme',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(AppColors.tripGradients.length, (index) {
                  final isSelected = createVm.coverGradientIndex == index;
                  final gradient = AppColors.getGradient(index);
                  return GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      createVm.setCoverGradientIndex(index);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: gradient[0].withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Add Initial Friends
              Text(
                'Add Friends (Optional)',
                style: AppTypography.titleSmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You can also share an invite link or join code after creating.',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _friendController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: "Friend's Name (e.g. Rahul)",
                        prefixIcon: Icon(Icons.person_add_outlined, size: 20),
                      ),
                      onSubmitted: (_) => _addFriend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _addFriend,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                      foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),

              if (createVm.friendNames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: createVm.friendNames.map((name) {
                    return Chip(
                      label: Text(name),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => createVm.removeFriendName(name),
                      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBorder),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Create CTA
              AppButton(
                text: 'Create Trip',
                icon: Icons.check_circle_outline_rounded,
                isFullWidth: true,
                isLoading: createVm.isCreating,
                onPressed: createVm.isValid ? _handleCreate : null,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
